#!/usr/bin/env bash

# this is a test file for experimenting with adding $'\cc' to the history file when the user hits ctrl-c
trap 'history -s "echo -n \"\""' INT
