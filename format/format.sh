#!/bin/bash

FORMATTERPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$JULIA_1112 --project=$FORMATTERPATH $FORMATTERPATH/format.jl
