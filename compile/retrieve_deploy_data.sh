#!/bin/bash

BASEPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$JULIA_1112 --project=$BASEPATH $BASEPATH/retrieve_deploy_data.jl $@