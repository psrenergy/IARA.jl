#!/bin/bash

# <description>
# 
# IARA_ecs.sh works as the entrypoint for the ECS task. Depending on the combination of envirnoment variables passed 
# to the task, it will execute different commands.
# The available environment variables passed to IARA are:
# 
# $IARA_URL: The URL to the IARA binaries in S3
# $IARA_COMMAND: The command to be executed
#  - "json and htmls for case creation"
#  - "heuristic bid"
#  - "single period market clearing"
# 
# $IARA_CASE: The path to the case folder in S3, it is a hash that identifies the case
#
# $IARA_GAME_ROUND: The round to be executed. It should be an integer
# 
# Usage:
#  $ ./IARA_ecs.sh

set -e

# Script variables
S3_BUCKET="meta-ccee-iara-artifacts"
CASE_PATH="iara-case"


function download_and_unzip_case () {
    echo "Downloading input data..."
    aws s3 cp s3://$S3_BUCKET/games/$IARA_CASE.zip ./$IARA_CASE.zip > /dev/null 2>&1
    unzip -qo $IARA_CASE.zip -d $CASE_PATH
    echo "Completed."
}

function validate_game_round () {
    if [ -z "$IARA_GAME_ROUND" ]; then
        echo "ERROR: Missing IARA_GAME_ROUND variable. Please provide the round to be executed"
        exit 1
    fi
    re='^[0-9]+$'
    if ! [[ $IARA_GAME_ROUND =~ $re ]] ; then
        echo "ERROR: IARA_GAME_ROUND should be a number" >&2
        exit 1
    fi
}

curl -o iara.zip $IARA_URL
unzip -qo iara.zip -d iara_model
rm iara.zip
mkdir /root/.julia
ln -s /IARA/iara_model/share/julia/artifacts/ /root/.julia/
IARA_PATH="$(pwd)/iara_model/bin"

if [ -z "$IARA_COMMAND" ]; then
    echo "ERROR: Missing IARA_COMMAND variable. Please provide the command to be executed" 
    exit 1
fi

if [ -z "$IARA_CASE" ]; then
    echo "ERROR: Missing IARA_CASE variable. Please provide the
    path to the case folder in S3, it is a hash that identifies the case"
    exit 1
fi

# Generate json and htmls for case creation
if [ "$IARA_COMMAND" == "json and htmls for case creation" ]; then

    download_and_unzip_case()

    $IARA_PATH/IARA_interface_call.sh --delete-output-folder-before-execution --run-mode 'min-cost' $CASE_PATH # TODO confirm shell script name
    
    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/outputs/ s3://$S3_BUCKET/$IARA_CASE/game_summary/ --recursive > /dev/null 2>&1
    echo "Completed."    
    exit 0
fi

# Generate heuristic bid
if [ "$IARA_COMMAND" == "heuristic bid" ]; then
    validate_game_round()
    download_and_unzip_case()

    $IARA_PATH/IARA.sh $CASE_PATH # TODO missing other arguments
    
    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/outputs/ s3://$S3_BUCKET/$IARA_CASE/game_round_$IARA_GAME_ROUND/heuristic_bids/ --recursive > /dev/null 2>&1
    echo "Completed."
    exit 0
fi

# Run single period market clearing
if [ "$IARA_COMMAND" == "single period market clearing" ]; then
    validate_game_round()
    download_and_unzip_case()

    $IARA_PATH/IARA.sh $CASE_PATH # TODO missing other arguments
    
    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/outputs/ s3://$S3_BUCKET/$IARA_CASE/game_round_$IARA_GAME_ROUND/results/ --recursive > /dev/null 2>&1
    echo "Completed."    
    exit 0
fi
