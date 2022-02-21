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

cloudWatchTaskId=$($scripts/launch-cloud-watch-export.sh "${from_date}" "${to_date}" "${destination_bucket}" "${destination_prefix}")

if [ -z "${cloudWatchTaskId}" ]; then
    # skipping an empty cloudwatch export (launch script will log message)
    exit 0
fi

echo "cloudWatchTaskId: ${cloudWatchTaskId}"

$scripts/wait-for-cloud-watch-task-completion.sh $cloudWatchTaskId

logs_uri="s3://${destination_bucket}/${destination_prefix}/$cloudWatchTaskId"

$scripts/download-from-cloudwatch.sh "${logs_uri}" "${target_dir}"
