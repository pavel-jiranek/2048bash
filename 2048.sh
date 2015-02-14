#!/bin/bash

# TODO Make the game-over detection.
# TODO Simplify the UI.
# TODO Add parameters from the command line.
# TODO Add the possibility to save the grid.
# TODO Keep some user config file with the highest score?

declare -i  nrows
declare -i  ncols
declare -ia grid
declare -i  grid_cols
declare -i  grid_rows
declare -i  grid_size
declare -i  grid_start_left
declare -i  grid_start_top
declare     grid_col_loop_fwd
declare     grid_col_loop_bwd
declare     grid_row_loop_fwd
declare     grid_row_loop_bwd
declare     grid_loop

declare -i  score

declare -a  colors_fg
declare -a  colors_bg
declare -a  value_rep

# Version
version_major=0
version_minor=0
version_patch=1

# Frame characters.
LT='/'
LM='|'
LB='\'
RT='\'
RM='|'
RB='/'
CT='-'
CM='+'
CB='-'
V='|'
H='-'

# Set some parameters.
desktop_bg=0
titstat_bg=39
titstat_fg=226
titstat_highlight_fg=206
statmsg_bg=124
statmsg_fg=255
statmsg_highlight_fg=11
grid_bg=145
grid_fg=0
grid_start_col=6
grid_start_row=4

grid_rows=6
grid_cols=6

# Number colors.
# TODO Instead of X use Y in X=2^Y, Bash can do powers!
colors_fg[0]="$grid_fg";colors_bg[0]="$grid_bg";
colors_fg[2]=234;       colors_bg[2]=255;
colors_fg[4]=234;       colors_bg[4]=252;
colors_fg[8]=255;       colors_bg[8]=215;
colors_fg[16]=255;      colors_bg[16]=208;
colors_fg[32]=255;      colors_bg[32]=167;
colors_fg[64]=255;      colors_bg[64]=197;
colors_fg[128]=255;     colors_bg[128]=214;
colors_fg[256]=255;     colors_bg[256]=214;
colors_fg[512]=255;     colors_bg[512]=214;
colors_fg[1024]=255;    colors_bg[1024]=241;
colors_fg[2048]=255;    colors_bg[2048]=241;
colors_fg[4096]=255;    colors_bg[4096]=232;
colors_fg[8192]=255;    colors_bg[8192]=232;
colors_fg[16384]=255;   colors_bg[16384]=26;
colors_fg[32768]=255;   colors_bg[32768]=36;
colors_fg[65536]=255;   colors_bg[65536]=36;
colors_fg[131072]=255;  colors_bg[131072]=124;
colors_fg[262144]=255;  colors_bg[262144]=124;
colors_fg[524288]=255;  colors_bg[524288]=124;

# Value representations.
value_rep[0]="    ";
value_rep[2]="  2 ";
value_rep[4]="  4 ";
value_rep[8]="  8 ";
value_rep[16]=" 16 ";
value_rep[32]=" 32 ";
value_rep[64]=" 64 ";
value_rep[128]=" 128";
value_rep[256]=" 256";
value_rep[512]=" 512";
value_rep[1024]="1024";
value_rep[2048]="2048";
value_rep[4096]="4096";
value_rep[8192]="8192";
value_rep[16384]="16k";
value_rep[32768]="32k";
value_rep[65536]="64k";
value_rep[131072]="128k";
value_rep[262144]="256k";
value_rep[524288]="512k";

# Write arguments to standard error.
function error_msg {
    >&2 echo $@
}

# Check the terminal: standard input and output must be a terminal and
# it should support 256 colors (because I like it).
function check_terminal {
    if [ ! -t 0 ]
    then
        error_msg "Input is not a terminal"
        return 1
    fi

    if [ ! -t 1 ]
    then
        error_msg "Output is not a terminal"
        return 1
    fi

    ncolors=$(tput colors)
    if [ "$ncolors" -ne "256" ]
    then
        error_msg "Terminal does not support 256 colors"
        return 1
    fi

    return 0
}

# Setup the environment.
function setup_environment {
    stty -echo                  # Set the terminal properties.
    trap "quit" SIGINT SIGTERM
}

# Draw the status bar.
function draw_status {
    tput cup $((nrows-1)) 0
    tput setab $titstat_bg
    tput setaf $titstat_fg
    printf "%${ncols}s" "Score: $score "
    tput cup $((nrows-1)) 0
    tput setaf $titstat_highlight_fg; printf " asdw "; tput setaf $titstat_fg; printf "Move "
    tput setaf $titstat_highlight_fg; printf " R"; tput setaf $titstat_fg; printf "edraw UI "
    tput setaf $titstat_highlight_fg; printf " Q"; tput setaf $titstat_fg; printf "uit "
}

# Status message.
function status_msg {
    tput setab $statmsg_bg
    tput setaf $statmsg_fg
    tput cup $((nrows-1)) 0
    printf "%-${ncols}s" "$@"
    tput op
    sleep 1
    draw_status
}

# Clean the mess and quit the game.
function quit {
    # ... Say Bye!
    status_msg "Bye!!!"
    # ... Set the options of the terminal back.
    stty sane
    # ... Clear color settings, make the cursor visible, and clear the screen
    tput op
    tput cnorm
    tput clear
    # ... Then exit, ciao!
    exit
}

# Draw the basic UI.
function draw_ui {
    # ... Get the terminal size.
    nrows=$(tput lines)
    ncols=$(tput cols)
    # ... Hide the cursor.
    tput civis
    # ... Clear the screen.
    tput setab $desktop_bg
    tput clear
    # ... Draw the header.
    tput setab $titstat_bg
    tput setaf $titstat_fg
    tput cup 0 0
    printf "%${ncols}s" " "
    tput cup 0 0
    printf " 2048 for Bash v%d.%d.%d" $version_major $version_minor $version_patch
    # ... Draw the status bar (as a separate function since it may need to be
    #     redrawed occasionally).
    draw_status
    # ... Reset colors.
    tput op
}

# Initialize the grid.
function init_grid {
    # ... Set the number of columns and rows and the total grid size.
    #     (grid_rows and grid_cols are set already)
    grid_size=$((grid_cols * grid_rows))
    # ... Create the variables for looping (to avoid all to calls to seq).
    grid_col_loop_fwd=$(seq 0 $((grid_cols-1)))
    grid_col_loop_bwd=$(seq $((grid_cols-1)) -1 0)
    grid_row_loop_fwd=$(seq 0 $((grid_rows-1)))
    grid_row_loop_bwd=$(seq $((grid_rows-1)) -1 0)
    grid_loop=$(seq 0 $((grid_size-1)))
    # ... Fill the grid with zeros.
    grid=()
    for i in $grid_loop; do grid[$i]=0; done
}

# Insert random numbers to the grid.
function insert_random {
    # TODO Make a better choice of random positions
    # TODO to avoid the infinite while loop.
    local num=$1
    local values=($2)
    local num_f=$(num_free)
    if [ "$num" -gt "$num_f" ]
    then
        num=$num_f
    fi
    local num_values=${#values[*]}
    for i in $(seq 1 $num)
    do
        value=${values[$((RANDOM % num_values))]}
        while :
        do
            position=$((RANDOM % grid_size))
            if [ ${grid[$position]} -eq "0" ]; then break; fi
        done
        grid[$position]=$value
    done
}

# Draw the grid frame.
function draw_grid_frame {
    tput setaf $grid_fg
    tput setab $grid_bg
    for i in $grid_col_loop_fwd
    do
        for j in $grid_row_loop_fwd
        do
            if [ $i -eq 0 ]; then
                if [ $j -eq 0 ]; then
                    tl="$LT"; tr="$CT"; bl="$LM"; br="$CM"
                elif [ $j -eq $((grid_rows-1)) ]; then
                    tl="$LM"; tr="$CM"; bl="$LB"; br="$tr"
                else
                    tl="$LM"; tr="$CM"; bl="$tl"; br="$tr"
                fi
            elif [ $i -eq $((grid_cols-1)) ]; then
                if [ $j -eq 0 ]; then
                    tl="$CT"; tr="$RT"; bl="$CM"; br="$RM"
                elif [ $j -eq $((grid_rows-1)) ]; then
                    tl="$CM"; tr="$LM"; bl="$CB"; br="$RB"
                else
                    tl="$CM"; tr="$RM"; bl="$tl"; br="$br"
                fi
            else
                if [ $j -eq 0 ]; then
                    tl="$CT"; tr="$tl"; bl="$CM"; br="$bl"
                elif [ $j -eq $((grid_rows-1)) ]; then
                    tl="$CM"; tr="$tl"; bl="$CB"; br="$bl"
                else
                    tl="$CM"; tr="$tl"; bl="$tl"; br="$tl"
                fi
            fi

            x=$((grid_start_col + i * 5))
            y=$((grid_start_row  + j * 2))
            tput cup $y $x
            printf "%s" "$tl----$tr"
            tput cup $((y+1)) $x
            printf "%s" "$V    $V"
            tput cup $((y+2)) $x
            printf "%s" "$bl----$br"
        done
    done
    tput op
}

# Get the number of free fields.
function num_free {
    local num=0
    for i in ${!grid[*]}
    do
        if [ "${grid[$i]}" -eq "0" ]
        then
            num=$((num+1))
        fi
    done
    echo $num
}

# Draw grid.
function draw_grid {
    for i in $grid_col_loop_fwd
    do
        for j in $grid_row_loop_fwd
        do
            k=$((grid_rows * i + j))
            x=$((grid_start_col + i * 5 + 1))
            y=$((grid_start_row  + j * 2 + 1))
            tput cup $y $x
            value=${grid[$k]}
            cfg=${colors_fg[$value]}
            cbg=${colors_bg[$value]}
            tput setaf $cfg
            tput setab $cbg
            printf "${value_rep[${grid[$k]}]}"
        done
    done
    tput op
}

# Merge values.
#
# The function takes a string of values of a row or column and merges
# them according to the rules of 2048. The mergin is done towards the
# "left side" so the values must come in the correct order.
#
# It echoes the score made by the merge and the new values.
function merge_values {
    local values="$1"
    local mscore=0
    local new_values=
    local prev=0
    for val in $values; do
        if [ "$val" -eq "0" ]
        then
            continue
        fi

        if [ "$prev" -eq "0" ]
        then
            prev=$val
        else
            if [ "$val" -eq "$prev" ]
            then
                new_values="$new_values $((val * 2))"
                mscore=$(($mscore + $val * 2))
                prev=0
            else
                new_values="$new_values $prev"
                prev=$val
            fi
        fi
    done

    if [ "$prev" -ne "0" ]
    then
        new_values="$new_values $prev"
    fi

    echo "$mscore:$new_values"
}

# Get a column of the grid.
function get_col {
    col=$1
    rev=$2

    vals=
    if [ "$rev" -eq 0 ]
    then
        for row in $grid_row_loop_fwd
        do
            k=$((col*grid_rows+row))
            vals="$vals ${grid[$k]}"
        done
    else
        for row in $grid_row_loop_bwd
        do
            k=$((col*grid_rows+row))
            vals="$vals ${grid[$k]}"
        done
    fi

    echo $vals
}

# Get a row of the grid.
function get_row {
    row=$1
    rev=$2

    vals=
    if [ "$rev" -eq 0 ]
    then
        for col in $grid_col_loop_fwd
        do
            k=$((col*grid_rows+row))
            vals="$vals ${grid[$k]}"
        done
    else
        for col in $grid_col_loop_bwd
        do
            k=$((col*grid_rows+row))
            vals="$vals ${grid[$k]}"
        done
    fi

    echo $vals
}

# Set a column of the grid.
function set_col {
    col=$1
    values=($2)
    rev=$3

    # Zero out the column.
    for row in $grid_row_loop_fwd
    do
        k=$((col*grid_rows+row))
        grid[$k]=0
    done

    if [ "$rev" -eq 0 ]
    then
        for i in ${!values[*]}
        do
            k=$((col*grid_rows+i))
            grid[$k]=${values[$i]}
        done
    else
        for i in ${!values[*]}
        do
            j=$((grid_rows-i-1))
            k=$((col*grid_rows+j))
            grid[$k]=${values[$i]}
        done
    fi
}

# Set a row of the grid.
function set_row {
    row=$1
    values=($2)
    rev=$3

    # Zero out the row.
    for col in $grid_col_loop_fwd
    do
        k=$((col*grid_rows+row))
        grid[$k]=0
    done

    if [ "$rev" -eq 0 ]
    then
        for i in ${!values[*]}
        do
            k=$((i*grid_rows+row))
            grid[$k]=${values[$i]}
        done
    else
        for i in ${!values[*]}
        do
            j=$((grid_cols-i-1))
            k=$((j*grid_rows+row))
            grid[$k]=${values[$i]}
        done
    fi
}



# Make move.
function make_move {
    local where=$1
    case $where in
        up)
            for col in $grid_col_loop_fwd
            do
                values=$(get_col $col 0)
                stuff=$(merge_values "$values")
                mscore=$(echo $stuff | cut -f1 -d':')
                new_values=$(echo $stuff | cut -f2 -d':')
                score=$((score + mscore))
                set_col $col "$new_values" 0
            done
            ;;
        down)
            for col in $grid_col_loop_fwd
            do
                values=$(get_col $col 1)
                stuff=$(merge_values "$values")
                mscore=$(echo $stuff | cut -f1 -d':')
                new_values=$(echo $stuff | cut -f2 -d':')
                score=$((score + mscore))
                set_col $col "$new_values" 1
            done
            ;;
        left)
            for row in $grid_row_loop_fwd
            do
                values=$(get_row $row 0)
                stuff=$(merge_values "$values")
                mscore=$(echo $stuff | cut -f1 -d':')
                new_values=$(echo $stuff | cut -f2 -d':')
                score=$((score + mscore))
                set_row $row "$new_values" 0
            done
            ;;
        right)
            for row in $grid_row_loop_fwd
            do
                values=$(get_row $row 1)
                stuff=$(merge_values "$values")
                mscore=$(echo $stuff | cut -f1 -d':')
                new_values=$(echo $stuff | cut -f2 -d':')
                score=$((score + mscore))
                set_row $row "$new_values" 1
            done
            ;;
    esac
    insert_random 2 "2 4"
    draw_grid
    draw_status
}

# New game.
function new_game {
    score=0
    init_grid
    insert_random 2 "2"
    draw_ui
    draw_grid_frame
    draw_grid
}

# Redraw UI.
function redraw {
    draw_ui
    draw_grid_frame
    draw_grid
}

###############################################################################

# Check the terminal and exit if a bad thing happened.
check_terminal || exit

# Draw UI.
draw_ui

# Setup the environment.
setup_environment

# Initialize the game.
new_game

# The main control loop.
while :
do
    if read -s -n 1 ch
    then
        case $ch in
            a)  make_move left ;;
            d)  make_move right ;;
            w)  make_move up ;;
            s)  make_move down ;;
            n)  new_game ;;
            r)  redraw ;;
            q)  quit ;;
        esac
    fi
done

