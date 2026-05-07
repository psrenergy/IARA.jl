#!/bin/bash

FORMATTERPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

julia +1.11.2 --project=$FORMATTERPATH $FORMATTERPATH/format.jl
