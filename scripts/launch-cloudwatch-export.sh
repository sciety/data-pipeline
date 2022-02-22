#!/bin/bash

set -euo pipefail

if ! command -v gdate &> /dev/null
then
    DATE=date
else
    DATE=gdate
fi

from_date="$1"
to_date="$2"
destination_bucket="$3"
destination_prefix="$4"

if [ -z "${from_date}" ] || [ -z "${to_date}" ] || [ -z "${destination_bucket}" ] || [ -z "${destination_prefix}" ]; then
    echo "Usage: $0 <iso from date> <iso to date> <target dir> <destination bucket> <destination prefix>"
    exit 1
fi

if [ "${from_date}" == "${to_date}" ]; then
    >&2 echo "Not uploading cloudwatch ingress logs to BigQuery because it has already ran today."
    exit 0
fi

>&2 echo "Exporting from ${from_date} 00:00 to ${to_date} 00:00"
from_epoch_ms="$($DATE --date "${from_date} 00:00:00 +0000" +%s)000"
to_epoch_ms="$($DATE --date "${to_date} 00:00:00 +0000" +%s)000"

cloudwatch_task_id=$(aws logs create-export-task \
    --log-group-name '/aws/containerinsights/libero-eks--franklin/application' \
    --log-stream-name-prefix 'ingress-nginx-controller-' \
    --from  $from_epoch_ms \
    --to  $to_epoch_ms \
    --destination "${destination_bucket}" \
    --destination-prefix "${destination_prefix}" \
    | jq -r '.taskId')
echo $cloudwatch_task_id
