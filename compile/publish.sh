#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

julia +1.11.2 --project=$BASE_PATH $BASE_PATH/publish.jl $@
