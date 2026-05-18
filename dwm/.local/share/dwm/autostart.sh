run_once () {
    if ! pgrep -f ${1} > /dev/null
    then
        shift
        if command -v ${1} > /dev/null 2>&1 ; then
            $@ > ${1}.log &
        fi
    fi
}

focus_primary_monitor () {
    let x=3840/2+2160
    let y=2160/2
    if command -v xdotool > /dev/null 2>&1 ; then
        xdotool mousemove $x $y
        xdotool click 1
    fi
}

if [ `xrandr | grep "*" | awk '{print $1}' | grep 3840x2160 | head -n 1` = '3840x2160' ];
then
    sed -E -i 's/Xft.dpi: [0-9]+/Xft.dpi: 144/g' ~/.Xresources
else
    sed -E -i 's/Xft.dpi: [0-9]+/Xft.dpi: 144/g' ~/.Xresources
fi
xrdb -merge ~/.Xresources

# run_once dwm_bar.sh $HOME/.dwm/dwm-bar/dwm_bar.sh

autorandr -c --force
focus_primary_monitor

run_once emacs emacs
run_once zen-browser zen-browser
run_once volnoti volnoti
run_once dunst dunst
run_once pasystray pasystray -S
run_once picom picom
run_once dwmblocks dwmblocks
run_once ibus-daemon ibus-daemon -x -d
run_once feh feh --bg-tile ~/Documents/Wallpapers/mao.jpg --bg-fill ~/Documents/Wallpapers/mao_v.png
run_once Snipaste Snipaste
# run_once WeChat.exe WeChat
run_once Discord discord
run_once monitor_indicator monitor_indicator

focus_primary_monitor

if command -v xsetwacom > /dev/null 2>&1 ; then
    xsetwacom set 'Wacom One by Wacom S Pen stylus' Rotate half
    xsetwacom set 'Wacom One by Wacom S Pen stylus' MapToOutput HEAD-0
fi
