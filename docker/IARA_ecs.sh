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
export S3_BUCKET="meta-ccee-iara-artifacts"
export CASE_PATH="iara-case"

function download_and_unzip_complete_case () {
    echo "Downloading input data..."
    aws s3 cp s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/ ./$IARA_CASE --recursive --exclude "results/*" --exclude "*.log" --exclude "bids/bids.zip"

    unzip -qo ./$IARA_CASE/game_inputs.zip -d $CASE_PATH

    # unzip bids
    echo "Using volume path"
    unzip -qo $IARA_VOLUME/${IARA_CASE}_bids_round_${IARA_GAME_ROUND}/bids.zip -d $CASE_PATH

    
    # unzip heuristic bids 
    unzip -qo ./$IARA_CASE/heuristic_bids/heuristic_bids.zip -d $CASE_PATH/heuristic_bids

    mv $CASE_PATH/heuristic_bids/bidding_group_no_markup_price_bid_period_$IARA_GAME_ROUND.csv $CASE_PATH/bidding_group_no_markup_price_bid_period_$IARA_GAME_ROUND.csv 
    mv $CASE_PATH/heuristic_bids/bidding_group_no_markup_price_bid_period_$IARA_GAME_ROUND.toml $CASE_PATH/bidding_group_no_markup_price_bid_period_$IARA_GAME_ROUND.toml
    mv $CASE_PATH/heuristic_bids/bidding_group_energy_bid_period_$IARA_GAME_ROUND.csv $CASE_PATH/bidding_group_no_markup_energy_bid_period_$IARA_GAME_ROUND.csv
    mv $CASE_PATH/heuristic_bids/bidding_group_energy_bid_period_$IARA_GAME_ROUND.toml $CASE_PATH/bidding_group_no_markup_energy_bid_period_$IARA_GAME_ROUND.toml

    echo "Completed."
}

function download_and_unzip_case () {
    echo "Downloading input data..."
    if [ "$IARA_GAME_ROUND" -eq 1 ] || [ "$IARA_COMMAND" == "json and htmls for case creation" ]; then
        echo "Using volume path"
        unzip -qo $IARA_VOLUME/$IARA_CASE/game_inputs.zip -d $CASE_PATH
    else
        if ! wait_for_game_inputs_file; then
            echo "Erro: file game_inputs.zip not found on S3."
            exit 1
        fi
        
        echo "Downloading input data from previous round..."
        aws s3 cp s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/game_inputs.zip ./$IARA_CASE.zip
        unzip -qo $IARA_CASE.zip -d $CASE_PATH
    fi
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
    
    if [ "$IARA_COMMAND" == "single period market clearing" ]; then
        save_iara_log "results"
    elif [ "$IARA_COMMAND" == "heuristic bid" ]; then
        save_iara_log "heuristic_bids"
    elif [ "$IARA_COMMAND" == "json and htmls for case creation" ]; then
        save_iara_log "game_summary"
    fi
}

function save_iara_case_to_next_round() {
    echo "Preparing IARA case to next round..."
    next_round=$((IARA_GAME_ROUND + 1))
    
    echo "Moving all .json results to main case folder root..."
    mv $CASE_PATH/results/*.json $CASE_PATH/
    rm -rf $CASE_PATH/results

    echo "Zipping case..."
    cd $CASE_PATH
    zip -r ../$CASE_PATH.zip ./* -x "heuristic_bids/*" -x "results/*" 
    cd -

    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH.zip s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$next_round/game_inputs.zip 

    echo "Completed."
}

function save_iara_log() {
    echo "Saving IARA log from $1..."
    if [ -e "./$CASE_PATH/$1/iara.log" ]
        then
        if [ "$IARA_COMMAND" == "json and htmls for case creation"  ]; 
            then
            aws s3 cp ./$CASE_PATH/$1/iara.log s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/json_iara.log
        elif [ "$IARA_COMMAND" == "heuristic bid"  ]; 
            then
            aws s3 cp ./$CASE_PATH/$1/iara.log s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/heuristic_iara.log
        elif [ "$IARA_COMMAND" == "single period market clearing"  ]; 
            then
            aws s3 cp ./$CASE_PATH/$1/iara.log s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/market_clearing_iara.log
        fi
    else
        echo "IARA log not found in $1"
    fi
    echo "Completed."
}

function wait_for_game_inputs_file () {
    local timeout=60
    local interval=2
    local elapsed=0

    echo "Waiting for previous round file (timeout: ${timeout}s)..."

    while ! aws s3 ls s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/game_inputs.zip > /dev/null 2>&1; do
        if [ "$elapsed" -ge "$timeout" ]; then
            echo "Timeout: File not found"
            return 1
        fi
        echo "File not found. Waiting..."
        sleep $interval
        elapsed=$((elapsed + 5))
    done

    echo "File found."
    return 0
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

    save_iara_log "game_summary"

    echo "Zipping plots..."
    cd $CASE_PATH/game_summary/plots
    zip -r ../plots.zip ./*
    cd -

    echo "Removing plots folder..."
    rm -rf $CASE_PATH/game_summary/plots
    
    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/game_summary/ s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_summary/ --recursive  
    echo "Uploading game_inputs.zip to game_round_1 folder..."
    aws s3 cp $IARA_VOLUME/$IARA_CASE/game_inputs.zip s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_1/game_inputs.zip
    echo "Completed."    
    exit 0
fi

# Generate heuristic bid
if [ "$IARA_COMMAND" == "heuristic bid" ]; then
    validate_game_round
    download_and_unzip_case

    trap 'catch_iara_error' ERR

    $IARA_PATH/IARA.sh $CASE_PATH --output-path="heuristic_bids" --run-mode 'single-period-heuristic-bid' --period=$IARA_GAME_ROUND

    save_iara_log "heuristic_bids"

    echo "Zipping heuristic bids..."
    cd $CASE_PATH/heuristic_bids
    zip -r ../heuristic_bids.zip ./*
    cd -
    
    echo "Uploading results to S3..."
    aws s3 cp ./$CASE_PATH/heuristic_bids.zip s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/heuristic_bids/heuristic_bids.zip 

    echo "Completed."
    exit 0
fi

# Run single period market clearing
if [ "$IARA_COMMAND" == "single period market clearing" ]; then
    validate_game_round
    download_and_unzip_complete_case

    trap 'catch_iara_error' ERR

    $IARA_PATH/IARA.sh $CASE_PATH --output-path="results" --run-mode='single-period-market-clearing' --period=$IARA_GAME_ROUND --plot-ui-results

    save_iara_log "results"

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
    aws s3 cp $IARA_VOLUME/${IARA_CASE}_bids_round_${IARA_GAME_ROUND}/bids.zip s3://$S3_BUCKET/$IARA_FOLDER/$IARA_CASE/game_round_$IARA_GAME_ROUND/bids/bids.zip
    echo "Removing temp dir $IARA_VOLUME/$IARA_CASE..."
    rm -rf $IARA_VOLUME/${IARA_CASE}_bids_round_${IARA_GAME_ROUND}
    echo "$IARA_VOLUME/$IARA_CASE successfully removed"
    save_iara_case_to_next_round

    echo "Completed."    
    exit 0
fi
