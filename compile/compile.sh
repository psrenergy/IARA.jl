#!/bin/bash
set -e

BASEPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

julia +1.11.2 --project=$BASEPATH $BASEPATH/compile.jl $@