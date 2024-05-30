#!/usr/bin/env bash

tty_descriptor="$(tty)"

__profile__fn__log_raw() {
  while read line; do
    echo "${line}"
    if [[ ! ${line} =~ ^[A-Z]+ ]]; then
      echo -e "\e[1;34m\ECHO $(date +'%Y-%m-%d %H:%M:%S')\e[0m \e[1;31m[RAW]\e[0m ${line}"
      echo ""
    fi
  done
}

exec 2> >(__profile__fn__log_raw "first")
read -p "Enter your name: " input
echo "highli fj this should log" >&2
read -p "Enter your name: " input
echo "ERROR this should log" >&2
