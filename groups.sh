#/bin/bash

# TODO make it defaults to the current focused screen

usage() {
    cat << EOF
usage : $(basename $0) [screen] command arg1 arg2 ...
    screen must be the name of the xrandr output (defaults to the primary
        output).
    command must be one of these :
        - help : show this help.
        - toggle g1 [...]  : toggle the visibility of the groups passed as
                              arguments.
        - map g1 [...]     : map (show) the groups passed as arguments.
        - unmap g1 [...]   : unmap (hide) the groups passed as arguments.
        - set w g1 [...]   : add window w (given by wid) to the groups passed
                              as arguments.
        - unset w g1 [...] : remove window w (given by wid) from the groups
                              passed as arguments.
        - clean w          : remove window from all groups on all heads.
        - create g1 [...]  : create the groups passed as arguments (a group
                              must be created before it used). It does nothing
                              if the group already exists.
        - rm g1 g2 [...]   : remove the groups passed as arguments.

    When a window is added to groups in a screen, it is removed from all groups
    in any other screens.
EOF
}

# test for arguments
test $# -eq 0 && usage && exit 1

# It would be better to host it on a tmpfs filesystem, or at least on a
# filesystem that get cleared at reboot
GRDIR=${GRDIR:-/tmp/wm-tiles/groups}
test -d $GRDIR || init

init() {
    mkdir -p $GRDIR
    hds=`xrandr --current | awk 'BEGIN { FS=" " } / connected/ { print $1 }'`
    while read -r hd; do
        mkdir "$GRDIR/$hd"
    done <<< "`echo "$hds"`"
}

default_head() {
    head=`xrandr --current | awk 'BEGIN { FS=" " } /primary/ { print $1 }'`
}

create() {
    scr=$1
    gp=$2
    mkdir "$GRDIR/$scr/$gp"
    echo "unmapped" > "$GRDIR/$scr/$gp/mapping"
    touch "$GRDIR/$scr/$gp/windows"
}

delete() {
    scr=$1
    gp=$2
    rm -rf "$GRDIR/$scr/$gp"
}

map() {
    scr=$1
    gp=$2
    echo "mapped" > "$GRDIR/$scr/$gp/mapping"
    while read -r wid; do
        mapw -m "$wid"
    done < "$GRDIR/$scr/$gp/windows"
}

unmap() {
    scr=$1
    gp=$2
    echo "unmapped" > "$GRDIR/$scr/$gp/mapping"
    while read -r wid; do
        mapw -u "$wid"
    done < "$GRDIR/$scr/$gp/windows"
}

toggle() {
    scr=$1
    gp=$2
    if [ `cat "$GRDIR/$scr/$gp/mapping"` = "mapped" ]; then
        unmap $scr $gp
    else
        map $scr $gp
    fi
}

check() {
    scr=$1
    gp=$2
    return `test -d "$GRDIR/$scr/$gp"`
}

whas() {
    wid=$1
    scr=$2
    gp=$3
    str=`cat "$GRDIR/$scr/$gp/windows" | grep "$wid"`
    return `test -n "$str"`
}

wset() {
    wid=$1
    scr=$2
    gp=$3
    whas $wid $scr $gp || echo "$wid" >> "$GRDIR/$scr/$gp/windows"
    # TODO map if necessary
}

wunset() {
    wid=$1
    scr=$2
    gp=$3
    whas $wid $scr $gp && sed -i "/$wid/d" "$GRDIR/$scr/$gp/windows"
    # TODO unmap if necessary
}

cmd=$1
default_head
# Test if the first argument is a head or the command
   test $cmd != "help"   \
&& test $cmd != "toggle" \
&& test $cmd != "map"    \
&& test $cmd != "unmap"  \
&& test $cmd != "set"    \
&& test $cmd != "unset"  \
&& test $cmd != "clean"  \
&& test $cmd != "create" \
&& test $cmd != "rm"     \
&& (test $# -ge 2 || (usage && exit 1)) && cmd=$2 && head=$1 && shift

case $cmd in
    "help")
        usage && exit 0
        ;;

    "create")
        while [ -n "$2" ]; do
            check $head $2 || create $head $2
            shift
        done
        ;;
    "rm")
        while [ -n "$2" ]; do
            check $head $2 && delete $head $2
            shift
        done
        ;;

    "map")
        while [ -n "$2" ]; do
            check $head $2 && map $head $2
            shift
        done
        ;;
    "unmap")
        while [ -n "$2" ]; do
            check $head $2 && unmap $head $2
            shift
        done
        ;;
    "toggle")
        while [ -n "$2" ]; do
            check $head $2 && toggle $head $2
            shift
        done
        ;;

    "set")
        test -z "$2" && usage && exit 1
        wid=$2
        shift
        while [ -n "$2" ]; do
            check $head $2 && wset $wid $head $2
            shift
        done
        ;;
    "unset")
        test -z "$2" && usage && exit 1
        wid=$2
        shift
        while [ -n "$2" ]; do
            check $head $2 && wunset $wid $head $2
            shift
        done
        ;;

    *)
        usage && exit 1
        ;;
esac
