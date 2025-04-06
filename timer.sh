#!/bin/bash

# Global vars
time=0
title=""
rKey1=""
rKey2=""
sKey1=""
sKey2=""
startSuspended=false
restartOnSuspend=false
warnTime="$(grep "warn_time" "general.conf" | cut -d "=" -f 2 | xargs)"
WARN_SOUND="$(grep "warn_sound" "general.conf" | cut -d "=" -f 2 | xargs)"
PASS_SOUND="$(grep "pass_sound" "general.conf" | cut -d "=" -f 2 | xargs)"
INPUT_DEVICE="$(grep "input_device" "general.conf" | cut -d "=" -f 2 | xargs)"
TIMERS_DIR="timers"
RESTART_ARR=('' 'r' 'q' '/' 'ר')
# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;36m"
NC="\033[0m" # reset color

# Functions

print_help() {
    printf "Usage, Use one of the options, options in [] are optional:\n"
    printf "./timer.sh %b<time>%b\n" "${GREEN}" "${NC}"
    printf "./timer.sh %b<time>%b %b<title>%b [%b<restart key-combo>%b] [%b<suspend key-combo>%b]\n" "${GREEN}" "${NC}" "${GREEN}" "${NC}" "${GREEN}" "${NC}" "${GREEN}" "${NC}"
    printf "\nAlternatively use with one of these flags:\n"
    printf "%b-c <config>%b where %b<config>%b is a path to a .conf file\n" "${GREEN}" "${NC}" "${GREEN}" "${NC}"
    printf "%b-i%b for interactive selection of a config file in folder\n" "${GREEN}" "${NC}"
    printf "%b-s%b to start the timer paused\n" "${GREEN}" "${NC}"
    printf "%b--s-r%b to restart the timer when paused\n" "${GREEN}" "${NC}"
    printf "\n%b<time> format%b is either n/o seconds or %bXhXmX%b\n" "${GREEN}" "${NC}" "${YELLOW}" "${NC}"
    printf "where X is a number, h suffixes hours, m suffixes minutes and whatever comes next are added seconds\n"
    printf "Examples:\n"
    printf "120 = 120 seconds\n"
    printf "2m = 2 minutes\n"
    printf "5m2s = 5 minutes and 2 seconds\n"
    printf "1h2 = 1 hour and 2 seconds\n"
    printf "\n%b<key-combo> format is a list of exactly 2 keys delimited by a ','%b\n" "${GREEN}" "${NC}"
    printf "find which key is which using the command %bevtest%b\n" "${YELLOW}" "${NC}"
    printf "\n%bInterrupt keys%b when the timer is running:\n" "${GREEN}" "${NC}"
    printf "%b%s%b and %bEnter%b - To restart the timer\n" "${GREEN}" "${RESTART_ARR[*]}" "${NC}" "${GREEN}" "${NC}"
    printf "%bs%b - To suspend (pause) and resume the timer\n" "${GREEN}" "${NC}"
    printf "%be%b - To exit (quit) the timer - has to be pressed twice in a row\n" "${GREEN}" "${NC}"
    printf "\n%bConfig format:%b\n" "${GREEN}" "${NC}"
    printf "File must end with .conf and be inside a sub-dir under timers dir to appear in %b-i%b\n" "${GREEN}" "${NC}"
    printf "the sub-dirs under %btimers%b are used for categorization\n" "${BLUE}" "${NC}"
    printf "Must contain %btime=[time string]%b to set the timer's time\n" "${GREEN}" "${NC}"
    printf "Add %btitle=%b[title string]%b to set the timer's title\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %bsuspended=%btrue%b to start the timer paused\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %bsuspend_restarts=%btrue%b to restart the timer when paused\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %breset_keys=%b[keys list]%b to set the timer's reset key-combo\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %bsuspend_keys=%b[keys list]%b to set the timer's suspend key-combo\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %bwarn_time=%b[time in seconds]%b this overrides general.conf's time (see below)\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "\n%bgeneral.conf:%b\n" "${GREEN}" "${NC}"
    printf "If a file named \`general.conf\` is found withing the directory:\n"
    printf "Add %bwarn_time=%b[time in seconds]%b to set the remaining time where a warning should be displayed / played\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %bwarn_sound=%b[path to an ogg file]%b to play that file when %bwarn_time%b has passed\n" "${GREEN}" "${YELLOW}" "${NC}" "${GREEN}" "${NC}"
    printf "Add %bpass_sound=%b[path to an ogg file]%b to play that file when the timer expires\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %binput_device=%b[path to keyboard's /dev/input/eventX file]%b to use keycombos\n" "${GREEN}" "${YELLOW}" "${NC}"
}

# Background thread
time_int() {
    once=${1:-false}
    totalM=$(( time / 60000 ))
    totalS=$(( (time % 60000) / 1000 ))
    local played1=$once
    local played2=$once
    local first=true
    local blink=false
    while true; do
        ! $once && timeNow=$(date +%s%3N)
        passedMS=$(( timeNow - startTime ))
        remainMS=$(( time - passedMS ))
        signStr=""
        if [[ $passedMS -ge $time ]]; then
            printf "\a %b" "${RED}"
            blink=true
            if ! $played1; then
                [[ "$PASS_SOUND" != "" ]] && ! $first && ogg123 -q "$PASS_SOUND" &
                played1=true
            fi
            remainMS=$(( -1 * remainMS ))
            signStr="-"
        elif [[ $remainMS -le $(( warnTime * 1000 )) ]]; then
            printf "\a %b" "${RED}"
            if ! $played2; then
                [[ "$WARN_SOUND" != "" ]] && ! $first && ogg123 -q "$WARN_SOUND" &
                played2=true
            fi
        elif [[ $remainMS -le 60000 ]]; then
            printf "%b" "${YELLOW}"
        elif [[ $remainMS -le 120000 ]]; then
            printf "%b" "${BLUE}"
        fi
        passedM=$(( passedMS / 60000 ))
        passedS=$(( (passedMS % 60000) / 1000 ))
        remainM=$(( remainMS / 60000 ))
        remainS=$(( (remainMS % 60000) / 1000 ))
        roundedMS=$(( remainMS % 1000 ))
        if [[ $passedMS -lt $time ]] && [[ $roundedMS -gt 0 ]]; then
            if [[ $remainS -lt 59 ]]; then
                (( remainS++ ))
            else
                remainS=0
                (( remainM++ ))
            fi
        fi
        trap "" SIGTERM
        clear
        printf "%s " "${title}"
        if $once || ! $blink || [[ $roundedMS -lt 500 ]]; then
            printf "(%02d:%02d / %02d:%02d)\n" $passedM $passedS $totalM $totalS
        elif $blink; then
            printf "\n"
        else
            printf "\n"
        fi
        [[ $remainM == 0 ]] && [[ $remainS == 0 ]] && signStr=""
        figlet -t -k -- "$(printf -- "%s%02d:%02d" "${signStr}" $remainM $remainS)"
        # printf "ms: %s%03d\n" "${signStr}" $roundedMS
        addLine=false
        if [[ $rKey1 != "" ]] && [[ $rKey2 != "" ]]; then
            printf "restart: '%b%s+%s%b'" "${BLUE}" "${rKey1}" "${rKey2}" "${NC}"
            addLine=true
        fi
        if [[ $sKey1 != "" ]] && [[ $sKey2 != "" ]]; then
            printf " suspend: '%b%s+%s%b'" "${BLUE}" "${sKey1}" "${sKey2}" "${NC}"
            addLine=true
        fi
        $addLine && printf "\n\n"
        trap - SIGTERM
        $once && break
        first=false
        sleep 0.01
    done
}

time_kill() {
    [[ $ti_pid == "" ]] && return 0
    while ps -p "$ti_pid" > /dev/null; do
        kill -TERM "$ti_pid"
        sleep 0.1
    done
    ti_pid=""
}

# Sets the needed vars for this timer
# $1 = time via format
# returns the time in milliseconds
format_time() {
    local res=0
    local text=$1
    for (( i=0; i<${#text}; i++ )); do # foreach char
        local char="${text:$i:1}"
        local num=0
        while [[ $char =~ ^[0-9]+$ ]]; do
            num=$(( num * 10 ))
            num=$(( num + char ))
            (( i++ ))
            char="${text:$i:1}"
        done
        if [[ $char == 'm' ]]; then
            num=$(( num * 60 )) # minutes to seconds
        elif [[ $char == 'h' ]]; then
            num=$(( num * 3600 )) # hours to seconds
        fi
        res=$(( res + num ))
    done
    echo $(( res * 1000 ))
}

# inits vars from a given file
# $1 path to the config file 
init_config() {
    file=$1
    if ! [[ -f $file ]]; then
        echo "Config file does not exist!"
        exit 1
    fi
    time=$(format_time "$(grep "time" "$file" | cut -d "=" -f 2 | xargs)")
    title="$(grep "title" "$file" | cut -d "=" -f 2 | xargs)"
    if ! $startSuspended; then
        startSuspended=$(grep "suspended" "$file" | cut -d "=" -f 2 | xargs)
        [[ $startSuspended == "" ]] && startSuspended=false
    fi
    if ! $restartOnSuspend; then
        restartOnSuspend=$(grep "suspend_restarts" "$file" | cut -d "=" -f 2 | xargs)
        [[ $restartOnSuspend == "" ]] && restartOnSuspend=false
    fi
    resetKeys="$(grep "reset_keys" "$file" | cut -d "=" -f 2 | xargs)"
    rKey1=$(echo "$resetKeys" | cut -d "," -f 1)
    rKey2=$(echo "$resetKeys" | cut -d "," -f 2)
    suspendKeys="$(grep "suspend_keys" "$file" | cut -d "=" -f 2 | xargs)"
    sKey1=$(echo "$suspendKeys" | cut -d "," -f 1)
    sKey2=$(echo "$suspendKeys" | cut -d "," -f 2)
    if grep -q "warn_time" "$file"; then
        warnTime="$(grep "warn_time" "$file" | cut -d "=" -f 2 | xargs)"
    fi
}

# Args
while [[ $# -gt 0 ]]; do
case "${1}" in
    -c) # config file )
        if [[ $# != 2 ]]; then
            echo "Invalid number of arguments"
            print_help
            exit 1
        fi
        init_config "$2"
        shift
        shift
        ;;
    -i) # interactive )
        dirArr=()
        for dir in "$TIMERS_DIR"/*; do
            ! [ -d "$dir" ] && continue
            dirArr+=("$(echo "$dir" | cut -f 2 -d "/")")
        done
        selectedDir="$(printf "%s\n" "${dirArr[@]}" | fzy -p "directory > ")"
        files=()
        for file in "$TIMERS_DIR"/"$selectedDir"/*; do
            file=$(basename "$file")
            ext=$(echo "$file" | cut -f 2 -d ".")
            [[ $ext != "conf" ]] && continue
            file=$(echo "$file" | cut -f 1 -d ".")
            files+=("$file")
        done
        selectedFile="$(printf "%s\n" "${files[@]}" | fzy -p "file > ").conf"
        init_config "${TIMERS_DIR}/${selectedDir}/${selectedFile}"
        shift
        ;;
    -s) # suspend )
        startSuspended=true
        shift
        ;;
    --s-r) # restart on suspend )
        restartOnSuspend=true
        shift
        ;;
    -h|\?|--help) # help )
        print_help
        exit 1
        ;;
    -*) # unknown flag )
        printf "Invalid flag %b%s%b\n\n" "${BLUE}" "${1}" "${NC}"
        print_help
        exit 1
        ;;
    *) # directly from args )
        if [[ $# -lt 1 ]] || [[ $# -gt 4 ]]; then
            printf "Invalid number of arguments\n\n"
            print_help
            exit 1
        fi
        time=$(format_time "$1")
        title="$2"
        resetKeys="$3"
        suspendKeys="$4"
        rKey1=$(echo "$resetKeys" | cut -d "," -f 1)
        rKey2=$(echo "$resetKeys" | cut -d "," -f 2)
        sKey1=$(echo "$suspendKeys" | cut -d "," -f 1)
        sKey2=$(echo "$suspendKeys" | cut -d "," -f 2)
        shift
        shift
        shift
        shift
        ;;
esac
done

# Main logic
startTime=$(date +%s%3N)
suspendTime=$startTime
if ! $startSuspended; then
    time_int &
    ti_pid=$!
fi

lastKey=''
running=true
while $running; do
    key="none"
    while ! read -r -t 0.01 -n 1 key; do
        [[ $INPUT_DEVICE == "" ]] && continue
        if [[ $rKey1 != "" ]] && [[ $rKey2 != "" ]]; then
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${rKey1}" 2>&1 /dev/null
            key1Code=$?
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${rKey2}" 2>&1 /dev/null
            key2Code=$?
            if [[ $key1Code == 10 ]] && [[ $key2Code == 10 ]]; then
                key='r'
                break
            fi
        fi
        if [[ $sKey1 != "" ]] && [[ $sKey2 != "" ]]; then
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${sKey1}" 2>&1 /dev/null
            key1Code=$?
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${sKey2}" 2>&1 /dev/null
            key2Code=$?
            if [[ $key1Code == 10 ]] && [[ $key2Code == 10 ]]; then
                key='s'
                break
            fi
        fi
        if $startSuspended; then
            startSuspended=false
            key='s'
            timeNow=$(date +%s%3N)
            startTime=$timeNow
            suspendTime=$timeNow
            time_int true
            ti_pid=""
            printf "\r\b"
            printf "%bPAUSED%b Press%s to restart, s to continue & e to exit" "${GREEN}" "${NC}" "${RESTART_ARR[*]}"
            break
        fi
    done
    key="${key,,}"
    printf "\b \b"
    [[ $lastKey != 's' ]] && printf "\r"
    if [[ " ${RESTART_ARR[*]} " =~ " ${key} " ]]; then
        time_kill
        startTime=$(date +%s%3N)
        time_int &
        ti_pid=$!
    elif [[ $key == 's' ]]; then
        if [[ $lastKey == 's' ]]; then
            # handling resume
            timeNow=$(date +%s%3N)
            startTime=$(( timeNow - suspendTime ))
            time_int &
            ti_pid=$!
            lastKey=''
            continue
        fi
        time_kill
        timeNow=$(date +%s%3N)
        if $restartOnSuspend; then
            startTime=$timeNow
            suspendTime=0
        else
            timeNow=$(date +%s%3N)
            suspendTime=$(( timeNow - startTime ))
        fi
        time_int true
        printf "\r\b"
        printf "%bPAUSED%b Press%s to restart, s to continue & e to exit" "${GREEN}" "${NC}" "${RESTART_ARR[*]}"
    elif [[ $key == 'e' ]]; then
        if [[ $lastKey == 'e' ]] || [[ $lastKey == 's' ]]; then
            time_kill
            running=false
        fi
    fi
    lastKey=$key
done
