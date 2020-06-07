#!/bin/bash

if test ${BASH_VERSINFO[0]} -lt 4; then
    OLDBASH=Y
fi

set -f
read H W <<<"$(stty size)"
SIDE=25
W=$(( W - SIDE ))
DISPLAPOS=$((W + 2 ))
MAPSIZE=$(( W * H ))
GAMEPID=$$

#GAME OPTIONS
FLIGHT="(@)"
ASTEROID="*"
LIFE=5

#INIT VALUES
POS=$(( (W - SIDE - ${#FLIGHT}) / 2 ))
LASTPOS=$POS
MAP=""
SCORE=0
LINES=0
LEVEL=0

#DESIGNS
LEVELCUTS=(50 100 150 200 300 500 900 1500 3000 5000 9000 20000 60000)
DELAYS=(   10   9   8   7   6   6   6    5    5    5    4     4     4)
DENSITIES=(60  58  56  54  52  50  48   46   44   42   40    38    36)
NEXTLINE=${LEVELCUTS[$LEVEL]}
DELAY=${DELAYS[$LEVEL]}
DENSITY=${DENSITIES[$LEVEL]}

EMPTYFLIGHT="$(printf %${#FLIGHT}s '')"

hidecursor() {
    #HIDE
    echo -ne "\x1b[?25l"
    #RESET AUTO REPEAT
    echo -ne "\x1b[?8l"
    #ECHO OFF
    echo -ne "\x1b[?12l"
    #CLEAR SCREEN
    echo -ne "\x1b[2J"
    #MOVE LASTLINE
    echo -ne "\x1b[${H};0H"
    #SAVE POSITION AND CALL IT HOME
    echo -ne "\x1b[s"
}

drawflight() {
    local screenpos=$((POS + 1))
    BASEIDX=$(( (H - 1) * W ))
    LINE=${MAP:$BASEIDX:$W}
    COLLIDE="${LINE:$POS:${#FLIGHT}}"
    CHECKLINE=${CHECKLINE-0}
    while test "${COLLIDE## }" != "${COLLIDE}"; do COLLIDE="${COLLIDE## }";  done
    local H2=$((H - 2))
    if test "$CHECKLINE" != "$LINES" -a -n "${COLLIDE}"; then
        (( LIFE-- ))
        if test $LIFE -eq 0; then
            echo -ne "\x1b[${H};1H\x1bB"
            echo "SCORE: $SCORE"
            kill $GAMEPID 2>/dev/null
            exit
        fi
        echo -ne "\x1b[1;${DISPLAPOS}HCOLLISION"
    fi
    if test "$CHECKLINE" -ne "$LINES" -o "$LASTPOS" -eq "$POS"; then
        echo -ne "\x1b[${H};${screenpos}H${FLIGHT}"
    else
        if ((LASTPOS < POS)); then
            screenpos=$((screenpos - 1))
            echo -ne "\x1b[${H};${screenpos}H ${FLIGHT}"
        elif ((LASTPOS > POS)); then
            echo -ne "\x1b[${H};${screenpos}H${FLIGHT} "
        fi
    fi
    echo -ne "\x1b[${H};${DISPLAPOS}H LIVES:$LIFE SCORE:$SCORE $POS"
    CHECKLINE="$LINES"
}

mark() {
    #DRAW ASTEROID and WALL
    local loc="$1"
    local art="$2"
    local post=$(( loc + ${#art}))
    local screenpos=$(( loc + 1 ))
    echo -ne "\x1b[1;${screenpos}H${art}"

    TOPLINE="${TOPLINE:0:$loc}${art}${TOPLINE:$post}"
}

scroll() {
    exec <&-
    trap _left SIGUSR1
    trap _right SIGUSR2
    if test -z "$BASHPID"; then
        BASHPID=$(exec $BASH -c 'echo "$PPID"')
    fi
    BLANKLINE=$(printf %${W}s "")
    while true
    do
        #SCROLL DOWN
        echo -ne "\x1b[T"
        echo -ne "\x1b[1;${W}H|"

        (( LINES++ ))
        if (( LINES == $NEXTLINE )); then
            (( LEVEL++ ))
            echo -ne "\x1b[1;${DISPLAPOS}HLEVEL: $LEVEL"
            NEXTLINE=${LEVELCUTS[$LEVEL]:-$NEXTLINE}
            DELAY=${DELAYS[$LEVEL]:-$DELAY}
            DENSITY=${DENSITIES[$LEVEL]:-$DENSITY}
        fi
        if (( LINES > $H )); then
            (( SCORE++ ))
        fi

        TOPLINE="$BLANKLINE"
        REMAIN=W
        while (( REMAIN > 0 )); do
            if (( RANDOM % DENSITY < REMAIN )); then
                ASTERPOS=$(( RANDOM % W ))
                mark $ASTERPOS ${ASTEROID}
            fi
            (( REMAIN -= DENSITY ))
        done

        MAP="$TOPLINE$MAP"
        MAP="${MAP:0:$MAPSIZE}"

        drawflight

        COUNT=$DELAY
        while (( COUNT-- > 0 )); do
            kill -s SIGSTOP $BASHPID || exit
        done
    done
}

_exit() {
    #SHOW CURSOR
    echo -ne "\x1b[?25h"
    #SET AUTO REPEAT
    echo -ne "\x1b[?8h"
    #ECHO ON
    echo -ne "\x1b[?12h"
    kill $DRIVEPID $CLOCKPID 2>/dev/null || exit
    echo ""
    echo "BYE BYE!"
    exit
}
_left() {
    LASTPOS=$POS
    POS=$(( POS > 0 ? POS - 1 : POS ))
    drawflight
}
_right() {
    LASTPOS=$POS
    POS=$(( POS < W - ${#FLIGHT} - 1 ? POS + 1 : POS ))
    drawflight
}
_clock() {
    while true; do
       sleep $CLOCKPULSE
       kill -s SIGCONT $DRIVEPID
    done
}

trap _exit SIGINT SIGTERM

hidecursor
scroll &
DRIVEPID=$!
CLOCKPULSE=.005

if test -n "$OLDBASH"; then
    _clock &
    CLOCKPID=$!
fi

while true
do
    key=""
    if test -n "$OLDBASH"; then
        read -s -n1 key
    else
        read -s -n1 -t $CLOCKPULSE key
    fi
    case "$key" in
        j|h)
            kill -SIGUSR1 $DRIVEPID || exit
            continue
            ;;
        k|l)
            kill -SIGUSR2 $DRIVEPID || exit
            continue
            ;;
        q)
            _exit
            ;;
    esac
    if test -z "$OLDBASH"; then
        kill -s SIGCONT $DRIVEPID || exit
    fi
done
