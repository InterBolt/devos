#!/usr/bin/env bash

cd /Users/colinlaptop/tmkmk/solos

if [[ ! -e /etc/solos ]]; then
  echo "YAY: NOT FOUND"
fi
if [[ -e test.sh ]]; then
  echo "YAY: FOUND"
fi
if [[ -e bin/shared ]]; then
  echo "YAY: FOUND"
fi
