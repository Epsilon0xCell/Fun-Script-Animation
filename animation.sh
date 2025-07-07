#!/bin/bash

# Enhanced terminal animation

# Terminal dimensions
width=$(tput cols)
height=$(tput lines)

# Rocket initial state
x=0
y=$((height / 2))
x_speed=2
y_dir=1
y_amp=5
y_step=0.1
angle=0

# Starfield
num_stars=50
declare -a stars_x
declare -a stars_y
declare -a stars_char

# Colors
C_ROCKET="\033[1;31m" # Red
C_STARS="\033[1;33m"  # Yellow
C_RESET="\033[0m"

# Generate stars
for ((i=0; i<num_stars; i++)); do
    stars_x[$i]=$((RANDOM % width))
    stars_y[$i]=$((RANDOM % height))
    # Use different characters for twinkling effect
    case $((RANDOM % 3)) in
        0) stars_char[$i]="." ;;
        1) stars_char[$i]="*" ;;
        2) stars_char[$i]="+" ;;
    esac
done

# Hide cursor and clear screen
tput civis
clear

# Animation loop
while true; do
    # Start drawing
    buffer=""

    # Draw stars
    for ((i=0; i<num_stars; i++)); do
        buffer+=$(printf "\033[%s;%sH%s%s%s" "${stars_y[$i]}" "${stars_x[$i]}" "$C_STARS" "${stars_char[$i]}" "$C_RESET")
    done

    # Draw rocket
    buffer+=$(printf "\033[%s;%sH%s🚀%s" "$y" "$x" "$C_ROCKET" "$C_RESET")

    # Print buffer to screen
    echo -ne "$buffer"

    # Update rocket position
    # Horizontal movement
    x=$((x + x_speed))
    if [ $x -ge $((width - 2)) ] || [ $x -le 0 ]; then
        x_speed=$((x_speed * -1))
    fi

    # Vertical movement (sine wave)
    angle=$(echo "$angle + $y_step" | bc -l)
    y_offset=$(echo "$y_amp * s($angle)" | bc -l)
    y=$(( height / 2 + $(printf "%.0f" "$y_offset") ))


    sleep 0.05
done

# Restore cursor on exit (e.g., with Ctrl+C)
trap "tput cnorm" EXIT