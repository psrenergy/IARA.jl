#!/bin/bash

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REVISE_PATH="$BASE_PATH/revise"

$JULIA_1100 --project=$REVISE_PATH --load=$REVISE_PATH/revise_load_script.jl