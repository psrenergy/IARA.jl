#!/bin/bash

FORMATTERPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$JULIA_1100 --project=$FORMATTERPATH $FORMATTERPATH/format.jl
