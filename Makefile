all: install

dwm:
	stow -t ${HOME} -R dwm

dwl:
	stow -t ${HOME} -R dwl

zsh:
	stow -t ${HOME} -R zsh

formatter:
	stow -t ${HOME} -R formatter

picom:
	stow -t ${HOME} -R picom

rofi:
	stow -t ${HOME} -R rofi

Xorg:
	stow -t ${HOME} -R Xorg

rime-ice:
	git submodule update --init
	stow -t ${HOME} -R rime-ice

git:
	stow -t ${HOME} -R git

starship:
	stow -t ${HOME} -R starship

wechat:
	stow -t ${HOME} -R wechat

dunst:
	stow -t ${HOME} -R dunst

kitty:
	stow -t ${HOME} -R kitty

gdb:
	stow -t ${HOME} -R gdb

xremap:
	stow -t ${HOME} -R xremap

tmux:
	stow -t ${HOME} -R tmux

touchpad-rotate:
	mkdir -p touchpad-rotate/.local/bin
	cc -O2 -Wall -Wextra `pkg-config --cflags libevdev` \
	  -o touchpad-rotate/.local/bin/touchpad-rotate \
	  touchpad-rotate/touchpad-rotate.c \
	  `pkg-config --libs libevdev`
	stow -t ${HOME} -R touchpad-rotate
	sudo install -D -m 644 touchpad-rotate/system/xorg.conf.d/40-magic-trackpad.conf /etc/X11/xorg.conf.d/40-magic-trackpad.conf
	systemctl --user daemon-reload
	systemctl --user enable --now touchpad-rotate.service

install: dwm dwl formatter picom rofi Xorg rime-ice starship wechat dunst kitty gdb git zsh xremap tmux touchpad-rotate

.PHONY: all install dwl dwm formatter picom rofi Xorg rime-ice starship wechat dunst kitty gdb git zsh xremap tmux touchpad-rotate
