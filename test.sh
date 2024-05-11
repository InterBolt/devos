#!/usr/bin/env bash

FILE="/tmp/tmp.zzlmc7S1PB/solos.code-workspace"

grep -o "__v[A-Z0-9_]*__" "${FILE}" | sed 's/__//g'
