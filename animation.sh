#!/bin/bash

# I wrote this as a small terminal show with no ending of its own: a
# rocket crosses a fixed starfield on a sine wave until I stop it with
# Ctrl+C. Everything I care about below is keeping that loop honest on
# terminals that are smaller, slower, or missing tools than mine.

# I compute the vertical motion with bc, twice per frame. Without bc
# those two calls fail on every frame, the offsets come out empty, and
# the script spams errors while the rocket never moves. I would rather
# fail once, up front, with the actual reason.
if ! command -v bc >/dev/null 2>&1; then
    echo "animation.sh needs bc for the sine-wave motion, and bc was not found in PATH." >&2
    exit 1
fi

# I read the terminal size once, here, and I fall back to 80 by 24 when
# tput cannot report one, so a zero or missing size never reaches the
# division by height below. Reading it once is also my known limit: if
# the window is resized while the animation runs, I keep drawing for
# the old size until the script is restarted.
width=$(tput cols 2>/dev/null || echo 80)
height=$(tput lines 2>/dev/null || echo 24)
[ "$width" -gt 0 ] 2>/dev/null || width=80
[ "$height" -gt 0 ] 2>/dev/null || height=24

# I register the cursor restore before anything can hide the cursor,
# and before the loop. The first version of this script put the trap
# after the infinite loop, where it could never run, so Ctrl+C left
# the cursor hidden. I trap EXIT only, on purpose: trapping INT
# without exiting would swallow Ctrl+C and the animation would
# never stop.
trap "tput cnorm" EXIT

# I start the rocket at column 1 and on the middle row because ANSI
# cursor positions count from 1, not 0. A row or column of 0 in a
# position escape is invalid, so every position I generate in this
# script stays at 1 or above.
x=1
y=$((height / 2))
x_speed=2
y_amp=5
y_step=0.1
angle=0

num_stars=50
declare -a stars_x
declare -a stars_y
declare -a stars_char

# I store these colours as literal backslash sequences, not as actual
# escape bytes. printf passes them through untouched when it builds a
# frame, and only the final echo -ne interprets them. If I ever print
# the buffer without -e, the colours are the first thing that breaks.
C_ROCKET="\033[1;31m" # Red
C_STARS="\033[1;33m"  # Yellow
C_RESET="\033[0m"

# I place the stars once, before the loop, and they never move after
# this. Only the rocket moves. The plus 1 in both placements keeps a
# star off row and column 0, for the same 1-based reason as the rocket.
for ((i=0; i<num_stars; i++)); do
    stars_x[$i]=$((1 + RANDOM % width))
    stars_y[$i]=$((1 + RANDOM % height))
    # I pick each star's character once, here, so a given star keeps
    # the same character for the whole run. The variety is across the
    # field, not over time; nothing in the loop ever re-rolls these.
    case $((RANDOM % 3)) in
        0) stars_char[$i]="." ;;
        1) stars_char[$i]="*" ;;
        2) stars_char[$i]="+" ;;
    esac
done

# I hide the cursor only after the EXIT trap above is registered, so
# there is no window where the cursor is hidden with no restore set up.
tput civis
clear

while true; do
    # I assemble each frame in one string and print it with a single
    # write. If I printed the 50 stars and the rocket as separate
    # writes, the terminal could repaint between them, and that reads
    # as flicker. One buffer per frame keeps the whole frame atomic.
    buffer=""

    for ((i=0; i<num_stars; i++)); do
        buffer+=$(printf "\033[%s;%sH%s%s%s" "${stars_y[$i]}" "${stars_x[$i]}" "$C_STARS" "${stars_char[$i]}" "$C_RESET")
    done

    buffer+=$(printf "\033[%s;%sH%s🚀%s" "$y" "$x" "$C_ROCKET" "$C_RESET")

    echo -ne "$buffer"

    # I test the bounce with >= and <=, never with equality, because
    # the rocket moves two columns per frame and can step straight
    # past the exact edge column. An equality test would miss the
    # edge on those steps and the rocket would leave the screen.
    x=$((x + x_speed))
    if [ $x -ge $((width - 2)) ] || [ $x -le 1 ]; then
        x_speed=$((x_speed * -1))
    fi

    # I recompute y from the middle row on every frame instead of
    # adding an offset to the last y. The angle keeps growing through
    # bc, but the row itself is derived fresh each time, so the
    # rounding in the printf below cannot drift the rocket away from
    # the middle over a long run.
    angle=$(echo "$angle + $y_step" | bc -l)
    y_offset=$(echo "$y_amp * s($angle)" | bc -l)
    y=$(( height / 2 + $(printf "%.0f" "$y_offset") ))
    # My amplitude is fixed at 5 rows, so on a terminal shorter than
    # about 11 rows the wave would push the rocket to row 0 or past
    # the last row, and the position escape for those rows is invalid.
    # I clamp to the screen instead of trusting the terminal to be
    # tall enough for the wave I chose.
    [ "$y" -lt 1 ] && y=1
    [ "$y" -gt "$height" ] && y=$height


    # I pace the loop at about 20 frames per second. Without this
    # sleep the loop would spin as fast as the two bc calls per frame
    # allow, and the pacing would depend on the machine instead of me.
    sleep 0.05
done