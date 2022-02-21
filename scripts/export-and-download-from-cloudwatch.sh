#!/bin/bash

set -euo pipefail

scripts=$(dirname $0)

from_date="$1"
to_date="$2"
target_dir="$3"

if [ -z "${from_date}" ] || [ -z "${to_date}" ] || [ -z "${target_dir}" ]; then
    echo "Usage: $0 <iso from date> <iso to date> <target dir>"
    exit 1
fi

destination_bucket="sciety-data-extractions"
destination_prefix="ingress-nginx-controller-$from_date-$to_date"

echo "destination_prefix: ${destination_prefix}"

cloudwatch_task_id=$($scripts/launch-cloudwatch-export.sh "${from_date}" "${to_date}" "${destination_bucket}" "${destination_prefix}")

if [ -z "${cloudwatch_task_id}" ]; then
    # skipping an empty cloudwatch export (launch script will log message)
    exit 0
fi

echo "cloudwatch_task_id: ${cloudwatch_task_id}"

$scripts/wait-for-cloudwatch-task-completion.sh $cloudwatch_task_id

logs_uri="s3://${destination_bucket}/${destination_prefix}/$cloudwatch_task_id"

$scripts/download-from-cloudwatch.sh "${logs_uri}" "${target_dir}"
