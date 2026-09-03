/* touchpad-rotate.c — per-device touchpad rotation shim.
 *
 * Grabs all evdev devices whose names contain a substring, creates uinput
 * clones with rotated ABS_X / ABS_Y / ABS_MT_POSITION_X / ABS_MT_POSITION_Y
 * coordinates, and forwards events. libinput then sees the virtual,
 * already-rotated devices.
 *
 * Build: cc -O2 -Wall $(pkg-config --cflags libevdev) \
 *            -o .local/bin/touchpad-rotate touchpad-rotate.c \
 *            $(pkg-config --libs libevdev)
 *        The binary lives in .local/bin so stow links it to ~/.local/bin,
 *        which is where the systemd unit's ExecStart points.
 * Usage: touchpad-rotate -n NAME_SUBSTR -r {0|90|180|270}
 */
#define _POSIX_C_SOURCE 200809L

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <libevdev/libevdev.h>
#include <libevdev/libevdev-uinput.h>
#include <linux/input.h>

#define MAX_DEVS 8

struct rdev {
	int fd;
	struct libevdev *src;
	struct libevdev_uinput *uidev;
	int x_lo, x_hi, y_lo, y_hi;
	int mtx_lo, mtx_hi, mty_lo, mty_hi;
};

static struct rdev devs[MAX_DEVS];
static int n_devs = 0;
static int rotation = 0;
static const char *name_match = NULL;
static volatile sig_atomic_t stop = 0;

static void on_signal(int s) { (void)s; stop = 1; }

static void
transform_event(const struct rdev *d, struct input_event *ev)
{
	if (ev->type != EV_ABS) return;
	switch (ev->code) {
	case ABS_X:
		switch (rotation) {
		case 90:  ev->code = ABS_Y; break;
		case 180: ev->value = d->x_lo + d->x_hi - ev->value; break;
		case 270: ev->code = ABS_Y; ev->value = d->x_lo + d->x_hi - ev->value; break;
		}
		break;
	case ABS_Y:
		switch (rotation) {
		case 90:  ev->code = ABS_X; ev->value = d->y_lo + d->y_hi - ev->value; break;
		case 180: ev->value = d->y_lo + d->y_hi - ev->value; break;
		case 270: ev->code = ABS_X; break;
		}
		break;
	case ABS_MT_POSITION_X:
		switch (rotation) {
		case 90:  ev->code = ABS_MT_POSITION_Y; break;
		case 180: ev->value = d->mtx_lo + d->mtx_hi - ev->value; break;
		case 270: ev->code = ABS_MT_POSITION_Y; ev->value = d->mtx_lo + d->mtx_hi - ev->value; break;
		}
		break;
	case ABS_MT_POSITION_Y:
		switch (rotation) {
		case 90:  ev->code = ABS_MT_POSITION_X; ev->value = d->mty_lo + d->mty_hi - ev->value; break;
		case 180: ev->value = d->mty_lo + d->mty_hi - ev->value; break;
		case 270: ev->code = ABS_MT_POSITION_X; break;
		}
		break;
	}
}

/* For 90°/270° we swap the virtual device's X/Y axis info so libinput sees
 * the rotated ranges. 180° leaves codes alone, only values flip at runtime. */
static void
swap_axis_info(struct libevdev *dev)
{
	const struct input_absinfo *xi, *yi, *mxi, *myi;
	struct input_absinfo nx, ny;

	if ((xi = libevdev_get_abs_info(dev, ABS_X)) &&
	    (yi = libevdev_get_abs_info(dev, ABS_Y))) {
		nx = *yi; ny = *xi;
		libevdev_set_abs_info(dev, ABS_X, &nx);
		libevdev_set_abs_info(dev, ABS_Y, &ny);
	}
	if ((mxi = libevdev_get_abs_info(dev, ABS_MT_POSITION_X)) &&
	    (myi = libevdev_get_abs_info(dev, ABS_MT_POSITION_Y))) {
		nx = *myi; ny = *mxi;
		libevdev_set_abs_info(dev, ABS_MT_POSITION_X, &nx);
		libevdev_set_abs_info(dev, ABS_MT_POSITION_Y, &ny);
	}
}

static int
try_open_device(const char *path)
{
	int fd = open(path, O_RDONLY | O_NONBLOCK);
	if (fd < 0) return -1;

	struct libevdev *dev = NULL;
	if (libevdev_new_from_fd(fd, &dev) < 0) { close(fd); return -1; }

	const char *name = libevdev_get_name(dev);
	if (!name || !strstr(name, name_match)) {
		libevdev_free(dev); close(fd); return -1;
	}
	if (n_devs >= MAX_DEVS) {
		fprintf(stderr, "too many devices\n");
		libevdev_free(dev); close(fd); return -1;
	}

	struct rdev *r = &devs[n_devs];
	r->fd = fd;
	r->src = dev;

	const struct input_absinfo *xi = libevdev_get_abs_info(dev, ABS_X);
	const struct input_absinfo *yi = libevdev_get_abs_info(dev, ABS_Y);
	r->x_lo = xi ? xi->minimum : 0; r->x_hi = xi ? xi->maximum : 0;
	r->y_lo = yi ? yi->minimum : 0; r->y_hi = yi ? yi->maximum : 0;

	const struct input_absinfo *mxi = libevdev_get_abs_info(dev, ABS_MT_POSITION_X);
	const struct input_absinfo *myi = libevdev_get_abs_info(dev, ABS_MT_POSITION_Y);
	r->mtx_lo = mxi ? mxi->minimum : 0; r->mtx_hi = mxi ? mxi->maximum : 0;
	r->mty_lo = myi ? myi->minimum : 0; r->mty_hi = myi ? myi->maximum : 0;

	if (rotation == 90 || rotation == 270)
		swap_axis_info(dev);

	if (libevdev_grab(dev, LIBEVDEV_GRAB) < 0) {
		fprintf(stderr, "grab failed for %s: %s\n", path, strerror(errno));
		libevdev_free(dev); close(fd); return -1;
	}

	int err = libevdev_uinput_create_from_device(
	    dev, LIBEVDEV_UINPUT_OPEN_MANAGED, &r->uidev);
	if (err != 0) {
		fprintf(stderr, "uinput create failed for %s: %s\n",
		    path, strerror(-err));
		libevdev_grab(dev, LIBEVDEV_UNGRAB);
		libevdev_free(dev); close(fd); return -1;
	}

	n_devs++;
	fprintf(stderr, "rotated (%d°): %s (%s)\n", rotation, name, path);
	return 0;
}

static void
scan_devices(void)
{
	DIR *d = opendir("/dev/input");
	if (!d) { perror("opendir /dev/input"); exit(1); }
	struct dirent *e;
	while ((e = readdir(d))) {
		if (strncmp(e->d_name, "event", 5) != 0) continue;
		char path[272];
		snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
		try_open_device(path);
	}
	closedir(d);
}

static void
event_loop(void)
{
	struct pollfd pfds[MAX_DEVS];
	for (int i = 0; i < n_devs; i++) {
		pfds[i].fd = devs[i].fd;
		pfds[i].events = POLLIN;
	}
	while (!stop) {
		int n = poll(pfds, n_devs, -1);
		if (n < 0) {
			if (errno == EINTR) continue;
			perror("poll"); return;
		}
		for (int i = 0; i < n_devs; i++) {
			/* An unplugged device reports POLLERR/POLLHUP, never
			 * POLLIN, so the read below would never run and poll()
			 * would spin at 100% CPU. Exit and let systemd restart
			 * us; the startup scan then re-grabs on reconnect. */
			if (pfds[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
				fprintf(stderr, "device went away, exiting\n");
				return;
			}
			if (!(pfds[i].revents & POLLIN)) continue;
			struct input_event ev;
			int rc;
			while ((rc = libevdev_next_event(
			    devs[i].src, LIBEVDEV_READ_FLAG_NORMAL, &ev))
			    == LIBEVDEV_READ_STATUS_SUCCESS) {
				transform_event(&devs[i], &ev);
				libevdev_uinput_write_event(
				    devs[i].uidev, ev.type, ev.code, ev.value);
			}
			if (rc == -ENODEV) {
				fprintf(stderr, "device disconnected, exiting\n");
				return;
			}
		}
	}
}

static void
cleanup(void)
{
	for (int i = 0; i < n_devs; i++) {
		if (devs[i].uidev) libevdev_uinput_destroy(devs[i].uidev);
		if (devs[i].src) {
			libevdev_grab(devs[i].src, LIBEVDEV_UNGRAB);
			libevdev_free(devs[i].src);
		}
		if (devs[i].fd >= 0) close(devs[i].fd);
	}
}

int
main(int argc, char **argv)
{
	int opt;
	while ((opt = getopt(argc, argv, "n:r:")) != -1) {
		if (opt == 'n') name_match = optarg;
		else if (opt == 'r') rotation = atoi(optarg);
	}
	if (!name_match) {
		fprintf(stderr, "usage: %s -n NAME_SUBSTR -r {0|90|180|270}\n", argv[0]);
		return 1;
	}
	if (rotation != 0 && rotation != 90 && rotation != 180 && rotation != 270) {
		fprintf(stderr, "rotation must be 0, 90, 180, or 270\n");
		return 1;
	}

	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);

	scan_devices();
	if (n_devs == 0) {
		fprintf(stderr, "no matching device found for: %s\n", name_match);
		return 2;
	}

	event_loop();
	cleanup();
	return 0;
}
