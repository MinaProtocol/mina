#!/bin/bash

COLOR_NONE='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_ORANGE='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_LIGHT_GRAY='\033[0;37m'
COLOR_DARK_GRAY='\033[1;30m'
COLOR_BRIGHT_RED='\033[1;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_LIGHT_MAGENTA='\033[1;35m'

show_color=1
filters=()
file=""

while [ $# -gt 0 ]; do
  case "$1" in
  -f|--filter)
    filters+=("$2")
    shift
    shift
    ;;
  -n|--no-color)
    show_color=0
    shift
    ;;
  -*)
    echo "invalid argument: '$1'"
    exit 1
    ;;
  *)
    if [ -n "$file" ]; then
      echo "too many arguments"
      exit 1
    fi
    file="$1"
    shift
    ;;
  esac
done

format() {
  message="$(echo "$1" | jq -r "\"[\(.timestamp)]\(.path[0])$ \(.message)\"")"

  if [ "$show_color" -gt 0 ]; then
    case "$(echo "$1" | jq -r '.level')" in
    Trace)       color="$COLOR_CYAN";;
    Debug)       color="$COLOR_GREEN";;
    Info)        color="$COLOR_MAGENTA";;
    Warn)        color="$COLOR_YELLOW";;
    Error)       color="$COLOR_RED";;
    Faulty_peer) color="$COLOR_ORANGE";;
    Fatal)       color="$COLOR_BRIGHT_RED";;
    *)           color="";;
    esac


    if [ -n "$color" ]; then
      printf "${color}${message}${COLOR_NONE}\\n"
    else
      printf "${COLOR_RED}UNHANDLED LEVEL:${COLOR_NONE}${message}\\n"
    fi
  else
    echo "$message"
  fi
}

# TODO: support multiple filters
case "${#filters[@]}" in
0) filter="true";;
1) filter="${filters[0]}";;
*)
  echo "multiple filters not supported yet"
  exit 1
  ;;
esac

while read line; do
  filtered_line="$(echo "$line" | jq "if $filter then . else empty end" 2>/dev/null)"
  if [ "$?" != "0" ]; then
    printf "${COLOR_ORANGE}ERROR WHILE PARSING: ${COLOR_LIGHT_MAGENTA}${line}${COLOR_NONE}\\n"
  elif [ -n "$filtered_line" ]; then
    format "$filtered_line"
  fi
done < "${file:-/dev/stdin}"
