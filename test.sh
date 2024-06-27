#!/bin/bash

fn.test() {
  echo "${1}asdf"
  echo "${2}asdf"
  echo "${3}asdf"
}

fn.test "" "" "ok"
