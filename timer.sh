#!/bin/bash

# Global vars
time=0
title=""
rKey1=""
rKey2=""
sKey1=""
sKey2=""
startSuspended=false
warnTime="$(grep "warn_time" "general.conf" | cut -d "=" -f 2 | xargs)"
WARN_SOUND="$(grep "warn_sound" "general.conf" | cut -d "=" -f 2 | xargs)"
PASS_SOUND="$(grep "pass_sound" "general.conf" | cut -d "=" -f 2 | xargs)"
INPUT_DEVICE="$(grep "input_device" "general.conf" | cut -d "=" -f 2 | xargs)"
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
    printf "%b-i%b to start the timer paused\n" "${GREEN}" "${NC}"
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
    printf "File must end with .conf to appear in %b-i%b\n" "${GREEN}" "${NC}"
    printf "Must contain %btime=[time string]%b to set the timer's time\n" "${GREEN}" "${NC}"
    printf "Add %btitle=%b[title string]%b to set the timer's title\n" "${GREEN}" "${YELLOW}" "${NC}"
    printf "Add %bsuspended=%btrue%b to start the timer paused\n" "${GREEN}" "${YELLOW}" "${NC}"
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
    totalM=$(( time / 60 ))
    totalS=$(( time % 60 ))
    local played1=false
    local played2=false
    local blinkC=0
    while true; do
        timeNow=$(date +%s)
        passedS=$(( timeNow - startTime ))
        remainS=$(( time - passedS ))
        signStr=""
        if [[ $passedS -ge $time ]]; then
            printf "\a %b" "${RED}"
            (( blinkC++ ))
            if [[ $played1 == false ]]; then
                [[ "$PASS_SOUND" != "" ]] && ogg123 -q "$PASS_SOUND" &
                played1=true
            fi
            remainS=$(( -1 * remainS ))
            signStr="-"
        elif [[ $remainS -le $warnTime ]]; then
            printf "\a %b" "${RED}"
            if [[ $played2 == false ]]; then
                [[ "$WARN_SOUND" != "" ]] && ogg123 -q "$WARN_SOUND" &
                played2=true
            fi
        elif [[ $remainS -le 60 ]]; then
            printf "%b" "${YELLOW}"
        elif [[ $remainS -le 120 ]]; then
            printf "%b" "${BLUE}"
        fi
        passedM=$(( passedS / 60 ))
        passedS=$(( passedS % 60 ))
        remainM=$(( remainS / 60 ))
        remainS=$(( remainS % 60 ))
        trap "" SIGTERM
        clear
        printf "%s " "${title}"
        if [[ $blinkC -lt 50 ]]; then
            printf "(%02d:%02d / %02d:%02d)\n" $passedM $passedS $totalM $totalS
        elif [[ $blinkC -lt 75 ]]; then
            printf "\n"
        else
            printf "\n"
            blinkC=0
        fi
        figlet -w 400 -m 0 -- "$(printf -- "%s%02d:%02d" "${signStr}" $remainM $remainS)"
        echo -e "${NC}"
        addLine=0
        if [[ $rKey1 != "" ]] && [[ $rKey2 != "" ]]; then
            printf "restart: '%b%s+%s%b'" "${BLUE}" "${rKey1}" "${rKey2}" "${NC}"
            addLine=1
        fi
        if [[ $sKey1 != "" ]] && [[ $sKey2 != "" ]]; then
            printf " suspend: '%b%s+%s%b'" "${BLUE}" "${sKey1}" "${sKey2}" "${NC}"
            addLine=1
        fi
        [[ $addLine == 1 ]] && printf "\n\n"
        trap - SIGTERM
        sleep 0.01
    done
}

# Sets the needed vars for this timer
# $1 = time via format
# returns the time in seconds
format_time() {
    local res=0
    local text=$1
    local mul=false
    for (( i=0; i<${#text}; i++ )); do # foreach char
        local char="${text:$i:1}"
        if [[ $char == 'm' ]]; then
            res=$(( res * 60 )) # minutes to seconds
            mul=true
            continue
        elif [[ $char == 'h' ]]; then
            res=$(( res * 3600 )) # hours to seconds
            mul=true
            continue
        elif [[ $char == 's' ]]; then
            continue # just skip it
        fi
        if [[ $mul != true ]]; then
            res=$(( res * 10 ))
            mul=false
        fi
        res=$(( res + char ))
    done
    echo $res
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
        echo "Choose a file: "
        files=()
        for file in *; do
            [[ $file == "general.conf" ]] && continue
            ext=$(echo "$file" | cut -f 2 -d ".")
            if ! [[ $ext == "conf" ]]; then
                continue
            fi
            file=$(echo "$file" | cut -f 1 -d ".")
            files+=("$file")
        done
        init_config "$(printf "%s\n" "${files[@]}" | fzy).conf"
        shift
        ;;
    -s) # suspend )
        startSuspended=true
        shift
        ;;
    -h|\?|--help)
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
startTime=$(date +%s)
suspendTime=$(date +%s)
time_int &
ti_pid=$!

lastKey=''
running=true
while $running; do
    key="none"
    while ! read -r -t 0.01 -n 1 key; do
        [[ $INPUT_DEVICE == "" ]] && continue
        if [[ $rKey1 != "" ]] && [[ $rKey2 != "" ]]; then
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${rKey1}"
            key1Code=$?
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${rKey2}"
            key2Code=$?
            if [[ $key1Code == 10 ]] && [[ $key2Code == 10 ]]; then
                key='r'
                break
            fi
        fi
        if [[ $sKey1 != "" ]] && [[ $sKey2 != "" ]]; then
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${sKey1}"
            key1Code=$?
            evtest --query "$INPUT_DEVICE" "EV_KEY" "KEY_${sKey2}"
            key2Code=$?
            if [[ $key1Code == 10 ]] && [[ $key2Code == 10 ]]; then
                key='s'
                break
            fi
        fi
        if $startSuspended; then
            startSuspended=false
            key='s'
            break
        fi
    done
    key="${key,,}"
    printf "\b \b"
    [[ $lastKey != 's' ]] && printf "\r"
    if [[ " ${RESTART_ARR[*]} " =~ " ${key} " ]]; then
        if [[ $ti_pid != "" ]]; then
            while ps -p "$ti_pid" > /dev/null; do
                kill -TERM "$ti_pid"
                sleep 0.1
            done
        fi
        ti_pid=""
        startTime=$(date +%s)
        time_int &
        ti_pid=$!
    elif [[ $key == 's' ]]; then
        if [[ $lastKey == 's' ]]; then
            # handling resume
            timeNow=$(date +%s)
            startTime=$(( timeNow - suspendTime ))
            time_int &
            ti_pid=$!
            lastKey=''
            continue
        fi
        if [[ $ti_pid != "" ]]; then
            while ps -p "$ti_pid" > /dev/null; do
                kill -TERM "$ti_pid"
                sleep 0.1
            done
        fi
        ti_pid=""
        timeNow=$(date +%s)
        suspendTime=$(( timeNow - startTime ))
        printf "\r\b"
        printf "%bPAUSED%b Press%s to restart, s to continue & e to exit" "${GREEN}" "${NC}" "${RESTART_ARR[*]}"
    elif [[ $key == 'e' ]]; then
        if [[ $lastKey == 'e' ]] || [[ $lastKey == 's' ]]; then
            if [[ $ti_pid != "" ]]; then
                while ps -p "$ti_pid" > /dev/null; do
                    kill -TERM "$ti_pid"
                    sleep 0.1
                done
            fi
            ti_pid=""
            running=false
        fi
    fi
    lastKey=$key
done
