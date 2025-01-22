#!/bin/bash

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$JULIA_1112 --project=$BASE_PATH $BASE_PATH/main.jl $@