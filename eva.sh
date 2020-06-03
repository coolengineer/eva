#!/bin/bash

set -f
read H W <<<"$(stty size)"
SIDE=20
W=$(( W - SIDE ))
DISPLAPOS=$((W + 2 ))
MAPSIZE=$(( W * H ))
GAMEPID=$$

#GAME OPTIONS
FLIGHT="(-@-)"
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
NEXTLINE=${LEVELCUTS[$LEVEL]}
DELAY=${DELAYS[$LEVEL]}

hidecursor() {
    #HIDE
    echo -ne "\x1b[?25l"
    #CLEAR SCREEN
    echo -ne "\x1b[2J"
    #ECHO OFF
    stty -echo raw
    #MOVE LASTLINE
    echo -ne "\x1b[${H};0H"
    #SAVE POSITION AND CALL IT HOME
    echo -ne "\x1b[s"
}

drawflight() {
    POS2=$(( POS - 1))
    BASEIDX=$(( (H - 1) * W ))
    LINE=${MAP:$BASEIDX:$W}
    COLLIDE=$(echo ${LINE:$POS2:${#FLIGHT}})
    echo "$LINE" >> log.txt
    if test -n "$COLLIDE"; then
        (( LIFE-- ))
        if test $LIFE -eq 0; then
            echo -ne "\x1b[${H};1H\x1bB"
            echo "SCORE: $SCORE"
            kill $GAMEPID 2>/dev/null
            exit
        fi
        echo -ne "\x1b[1;${DISPLAPOS}HCOLLISION"
    fi
    if ((LASTPOS < POS)); then
        echo -ne "\x1b[${H};${POS2}H ${FLIGHT}"
    elif ((POS < W - ${#FLIGHT})); then
        echo -ne "\x1b[${H};${POS}H${FLIGHT} "
    else
        echo -ne "\x1b[${H};${POS}H${FLIGHT}"
    fi
    echo -ne "\x1b[$((H-1));${DISPLAPOS}H LEVEL:$LEVEL     "
    echo -ne "\x1b[${H};${DISPLAPOS}H LIVES:$LIFE SCORE:$SCORE"
}
scroll() {
    trap _left SIGUSR1
    trap _right SIGUSR2
    trap 'echo "$MAP"  | tr : "\n" > a; exit' SIGTERM SIGINT
    while true
    do
        echo -ne "\x1b[T"

        (( LINES++ ))
        if (( LINES == $NEXTLINE )); then
            (( LEVEL++ ))
            echo -ne "\x1b[1;${DISPLAPOS}HLEVEL: $LEVEL"
            NEXTLINE=${LEVELCUTS[$LEVEL]:-$NEXTLINE}
            DELAY=${DELAYS[$LEVEL]:-$DELAY}
        fi
        if (( LINES > $H )); then
            (( SCORE++ ))
        fi

        ASTERPOS=$(( RANDOM % W + 1))
        #SCROLL DOWN
        #DRAW ASTEROID and WALL
        echo -ne "\x1b[0;${ASTERPOS}H${ASTEROID}"
        echo -ne "\x1b[0;${W}H|"

        PRE=$(( ASTERPOS + ${#ASTEROID} - 1 ))
        POST=$(( W - ASTERPOS - ${#ASTEROID} + 1))
        NEWLINE=$(printf "%${PRE}s%${POST}s" ${ASTEROID} "")
        MAP="$NEWLINE$MAP"
        MAP="${MAP:0:$MAPSIZE}"

        drawflight

        COUNT=$DELAY
        while (( COUNT-- > 0 ))
        do
            sleep .03
        done
    done
}
_exit() {
    echo -ne "\x1b[?25h"
    stty echo cooked
    kill $DRIVEPID 2>/dev/null || exit
    echo ""
    echo "BYE BYE!"
    exit
}
_left() {
    LASTPOS=$POS
    POS=$(( POS > 1 ? POS - 1 : POS ))
    drawflight
}
_right() {
    LASTPOS=$POS
    POS=$(( POS < W - ${#FLIGHT} ? POS + 1 : POS ))
    drawflight
}

trap _exit SIGINT SIGTERM

hidecursor
scroll &
DRIVEPID=$!

while true
do
    read -s -n1 key
    case "$key" in
        j|h)
            kill -SIGUSR1 $DRIVEPID
            ;;
        k|l)
            kill -SIGUSR2 $DRIVEPID
            ;;
        q)
            _exit
            ;;
    esac
done
