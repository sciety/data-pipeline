#!/bin/bash

set -euo pipefail

cloudwatch_task_id=$1

while true; do
    task_status=$(aws logs describe-export-tasks --task-id=$cloudwatch_task_id \
        | jq -r '.exportTasks[0].status.code')
    echo $task_status
    if [[ $task_status == COMPLETED ]]; then
        break
    fi
    if [[ $task_status == FAILED ]]; then
        exit 1
    fi
    sleep 10
done
