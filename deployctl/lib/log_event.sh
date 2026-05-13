#!/bin/bash

# shellcheck source=../../shared/constants.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../shared/constants.sh"

# Define the master log file location based on the architecture
LOG_FILE="$DEPLOYCTL_HISTORY_LOG"

# Ensure the log directory exists before trying to write to it
mkdir -p "$(dirname "$LOG_FILE")"

# ==========================================
# FUNCTION: log_event
# DESCRIPTION: Writes a formatted log entry to history.log
# USAGE: log_event <LEVEL> <OPERATION> <APP_NAME> <MESSAGE>
# ==========================================
log_event() {
    # Check if we have at least 4 arguments
    if [ "$#" -lt 4 ]; then
        echo "Logger Error: Missing arguments. Usage: log_event LEVEL OPERATION APP_NAME MESSAGE"
        return 1
    fi

    local level=$(echo "$1" | tr '[:lower:]' '[:upper:]') # Force uppercase (e.g., infos -> INFOS)
    local operation=$(echo "$2" | tr '[:lower:]' '[:upper:]') # Force uppercase (e.g., deploy -> DEPLOY)
    local app_name="$3"
    
    # Shift the first 3 arguments out of the way, so "$@" contains only the message text
    shift 3
    local message="$*"
    
    # Generate the timestamp exactly as defined in the diagram
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Construct the final string
    local log_entry="$timestamp [$level] [$operation] [$app_name] $message"
    
    # 1. Append to the official history.log file for inboxctl to read
    echo "$log_entry" >> "$LOG_FILE"
    
    # 2. Print to the terminal for YOU (DEV 2) to see while running deployctl
    # We add some basic terminal colors here to make debugging easier for you
    if [ "$level" == "ERROR" ]; then
        echo -e "\e[31m$log_entry\e[0m" # Red text for ERROR
    elif [ "$level" == "INFOS" ]; then
        echo -e "\e[32m$log_entry\e[0m" # Green text for INFOS
    else
        echo -e "\e[33m$log_entry\e[0m" # Yellow text for anything else (WARNING, etc.)
    fi
}