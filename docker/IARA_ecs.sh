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
# $IARA_GAME_ROUND: The period to be executed. It should be an integer
#
# Usage:
#  $ ./IARA_ecs.sh

set -e

# Script variables
S3_BUCKET="meta-ccee-iara-artifacts"
CASE_PATH="iara-case"

function download_and_unzip_case () {
    echo "Downloading input data..."
    if [ "$IARA_GAME_ROUND" -eq 1 ] || [ "$IARA_COMMAND" == "json and htmls for case creation" ]; then
        echo "Downloading input data from case creation..."
        aws s3 cp s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_inputs.zip ./$IARA_CASE.zip  
    else
        echo "Downloading input data from previous round..."
        aws s3 cp s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/game_inputs.zip ./$IARA_CASE.zip
    fi
    unzip -qo $IARA_CASE.zip -d $CASE_PATH
    echo "Completed."
}

function download_bids_and_move_to_case () {
    echo "Downloading bids..."
    echo $S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/bids/bids.zip 
    aws s3 cp s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/bids/bids.zip ./bids.zip  
    unzip -qo bids.zip -d $CASE_PATH
    rm -f bids.zip
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

function catch_iara_error() {
    local exit_code=$?
    echo "Error: IARA failed with exit code $exit_code"
    if [ -e './iara_error.log' ]
        then
            echo "Uploading error log to S3..."
            aws s3 cp ./iara_error.log s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/iara_error.log
            echo "Completed."
    fi
}

function get_heuristic_bid_no_markup() {
    echo "Downloading heuristic bid no markup price offer..."
    aws s3 cp s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/heuristic_bids/bidding_group_no_markup_price_offer_period_$IARA_GAME_ROUND.csv ./$CASE_PATH/bidding_group_no_markup_price_offer_period_$IARA_GAME_ROUND.csv
    aws s3 cp s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/heuristic_bids/bidding_group_no_markup_price_offer_period_$IARA_GAME_ROUND.toml ./$CASE_PATH/bidding_group_no_markup_price_offer_period_$IARA_GAME_ROUND.toml
    echo "Completed."
}

function save_iara_case_to_next_round() {
    echo "Preparing IARA case to next round..."
    next_round=$((IARA_GAME_ROUND + 1))
    
    echo "Moving all .json results to main case folder root..."
    mv $CASE_PATH/results/*.json $CASE_PATH/
    rm -rf $CASE_PATH/results

    echo "Zipping case..."
    cd $CASE_PATH
    zip -r ../$CASE_PATH.zip ./*
    cd -

    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH.zip s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$next_round/game_inputs.zip 

    echo "Completed."
}

if [ -z "$IARA_COMMAND" ]; then
    echo "ERROR: Missing IARA_COMMAND variable. Please provide the command to be executed" 
    exit 1
fi

if [ "$IARA_COMMAND" == "help" ]; then
   
    $IARA_PATH/IARA.sh  --help

    echo "Completed."

    exit 0
fi


if [ -z "$IARA_CASE" ]; then
    echo "ERROR: Missing IARA_CASE variable. Please provide the
    path to the case folder in S3, it is a hash that identifies the case"
    exit 1
fi

# Generate json and htmls for case creation
if [ "$IARA_COMMAND" == "json and htmls for case creation" ]; then

    download_and_unzip_case
    trap 'catch_iara_error' ERR

    $IARA_PATH/IARA.sh --output-path="game_summary" --run-mode 'interface-call' $CASE_PATH 

    echo "Zipping plots..."
    cd $CASE_PATH/game_summary/plots
    zip -r ../plots.zip ./*
    cd -

    echo "Removing plots folder..."
    rm -rf $CASE_PATH/game_summary/plots
    
    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/game_summary/ s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_summary/ --recursive  
    echo "Completed."    
    exit 0
fi

# Generate heuristic bid
if [ "$IARA_COMMAND" == "heuristic bid" ]; then
    validate_game_round
    download_and_unzip_case

    trap 'catch_iara_error' ERR

    $IARA_PATH/IARA.sh $CASE_PATH --output-path="heuristic_bids" --run-mode 'single-period-heuristic-bid' --period=$IARA_GAME_ROUND
    
    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/heuristic_bids/ s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/heuristic_bids/ --recursive  
    echo "Completed."
    exit 0
fi

# Run single period market clearing
if [ "$IARA_COMMAND" == "single period market clearing" ]; then
    validate_game_round
    download_and_unzip_case
    download_bids_and_move_to_case
    get_heuristic_bid_no_markup

    trap 'catch_iara_error' ERR

    $IARA_PATH/IARA.sh $CASE_PATH --output-path="results" --run-mode='single-period-market-clearing' --period=$IARA_GAME_ROUND --plot-ui-results

    # Check if plots are in the results folder
    if [ ! -d "$CASE_PATH/results/plots" ]; then
        echo "Warning: No plots were generated"
        exit 0
    fi

    echo "Zipping plots..."
    cd $CASE_PATH/results/plots
    zip -r ../plots.zip ./*
    cd -

    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/results/plots.zip s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/results/plots.zip  

    save_iara_case_to_next_round

    echo "Completed."    
    exit 0
fi
