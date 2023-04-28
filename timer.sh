#!/bin/bash

# Global vars
time=0
title=""
RESTART_ARR=('' 'r' 'q' '/' 'ר')
TWO_SOUND="$(sed '1!d' general.conf)"
ONE_SOUND="$(sed '2!d' general.conf)"
# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;36m"
NC="\033[0m" # reset color

# Functions

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
                ogg123 -q "$ONE_SOUND" &
                played1=true
            fi
            remainS=$(( -1 * remainS ))
            signStr="-"
        elif [[ $remainS -le 20 ]]; then
            printf "\a %b" "${RED}"
            if [[ $played2 == false ]]; then
                ogg123 -q "$TWO_SOUND" &
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
        clear
        printf "%s " "${title}"
        if [[ $blinkC != 4 ]]; then
            printf "(%02d:%02d / %02d:%02d)\n" $passedM $passedS $totalM $totalS
        else
            printf "\n"
            blinkC=0
        fi
        figlet -w 400 -m 0 -- "$(printf -- "%s%02d:%02d" "${signStr}" $remainM $remainS)"
        echo -e "${NC}"
        sleep 0.25
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
    time=$(format_time "$(sed '1!d' $file)")
    title="$(sed '2!d' $file)"
}

# Args
# while [[ $# -gt 0 ]]; do
# done
case "${1}" in
    -c) # config file
        init_config "$2"
        ;;
    -i) # interactive
        echo "Choose a file: "
        files=()
        i=0
        for file in *; do
            [[ $file == "general.conf" ]] && continue
            ext=$(echo "$file" | cut -f 2 -d ".")
            if ! [[ $ext == "conf" ]]; then
                continue
            fi
            (( i++ ))
            echo "${i}. ${file}"
            files+=("$file")
        done
        echo -n "> "
        read -r ans
        (( ans-- ))
        init_config "${files[$ans]}"
        ;;
    *) # directly from args
        time=$(format_time "$1")
        title="$2"
        ;;
esac

# Main logic
startTime=$(date +%s)
suspendTime=$(date +%s)
time_int &
ti_pid=$!

lastKey=''
running=true
while $running; do
    key="none"
    read -r -n 1 key
    key="${key,,}"
    printf "\b \b"
    [[ $lastKey != 's' ]] && printf "\r"
    if [[ " ${RESTART_ARR[*]} " =~ " ${key} " ]]; then
        [[ $ti_pid != "" ]] && kill -TSTP $ti_pid
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
        [[ $ti_pid != "" ]] && kill -TSTP $ti_pid
        ti_pid=""
        timeNow=$(date +%s)
        suspendTime=$(( timeNow - startTime ))
        printf "\r\b"
        printf "%bPAUSED%b Press%s to restart, s to continue & e to exit" "${GREEN}" "${NC}" "${RESTART_ARR[*]}"
    elif [[ $key == 'e' ]]; then
        if [[ $lastKey == 'e' ]] || [[ $lastKey == 's' ]]; then
            [[ $ti_pid != "" ]] && kill -TSTP $ti_pid
            ti_pid=""
            running=false
        fi
    fi
    lastKey=$key
done
