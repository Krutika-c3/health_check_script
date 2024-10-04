#!/bin/bash

source healthCheck.cfg

#Add logs
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $1" >> "$log_file"
}

#stop the application
stop_application() {
    log "Stopping Application running on port 8080..."

    kill -9 $(lsof -ti:8080) >> /dev/null

    if [[ $? -eq 0 ]]; then
        log "Application stopped"
    else
        log "Something went wrong while stopping the application"
    fi
}

main() {
    echo "--------------------------------------------------------------------------------------" >> $log_file
    log "STOP APPLICATION"
    echo "--------------------------------------------------------------------------------------" >> $log_file

    stop_application
}

main
