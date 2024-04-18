#!/usr/bin/env bash

grep -Eo 'v[A-Z0-9_]{2,}' "bin/solos.sh" | grep -v "#" | grep -v "_$" || echo ""
