#!/bin/bash
set -e

BASEPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

julia +1.12.5 --project=$BASEPATH $BASEPATH/publish.jl "$@"
