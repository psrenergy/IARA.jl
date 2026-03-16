#!/bin/bash

FORMATTERPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

julia --project=$FORMATTERPATH $FORMATTERPATH/format.jl
