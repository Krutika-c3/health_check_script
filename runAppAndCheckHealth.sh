#!/bin/bash

set -x

source healthCheck.cfg

#Add logs
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $1" >> "$log_file"
}

#checkout project
checkout_project(){
    cd "$project_location"
}

#build the project
build_project() {
    mvn clean install &>> /dev/null || { log "BUILD FAILURE"; exit 1; }
    log "BUILD SUCCESS"
}

#Start the application and check if the application is up in specified timeframe or not
start_application() {
    nohup java -jar "$jar_location" &>> $log_file &
    # Wait for the application to start for 30 seconds
    seconds=1
    while ((seconds <= application_startup_timeout))
    do
        response_code=$(curl -s -o /dev/null -w "%{http_code}" "$login_endpoint")
        if [[ response_code -eq 200 ]] 
        then
            log "Application is up and running."
            return 0 #exit from this method
        else
            log "Application is not yet running. Retrying for $seconds time"
            ((seconds++))
            sleep $retry_interval
        fi
    done

    #if application is still not running after specified seconds
    log "Application did not start within $application_startup_timeout seconds. Check $log_file for details."
    exit 1
}

#check the health of the application and if endpoint is up in specified retries or not
check_health() {
    local retries=1
    while true
    do
        log "Health endpoint is not yet available, Retrying for $retries time"
        local response
        response=$(curl -s -w "%{http_code}" "$health_endpoint") 
        if [[ $? -eq 0 ]]
        then   
            local response_code
            local status
            response_code=$(echo "$response" | tail -c 4)
            json_response=$(echo "$response" | rev | cut -c 4- | rev)
            status=$(echo "$json_response" | jq -r '.status')

            if [[ "$response_code" -eq 200 ]]
            then
                if [[ "$status" = "UP" ]]
                then
                    log "Health endpoint is accessible and UP"
                    break
                else
                    log "Health endpoint is accessible, but status is not UP"
                fi
            else
                log "Health endpoint is not accessible (Status code: $response_code)"
            fi
        fi
        if [[ "$retries" -ge "$max_retries_for_health_endpoint" ]]
        then
            log "Maximum retries $max_retries_for_health_endpoint reached. Health endpoint is not accessible."
            exit 1
        fi
        let retries++
        sleep "$retry_interval"
    done
}

main() {
    echo "--------------------------------------------------------------------------------------" >> $log_file
    log "START APPLICATION"
    echo "--------------------------------------------------------------------------------------" >> $log_file

    checkout_project
    build_project
    start_application
    check_health
}

main