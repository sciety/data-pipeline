#!/bin/bash

set -euo pipefail

local_cloudwatch_dir="$1"
target_jsonl_file="$2"

if [ -z "${local_cloudwatch_dir}" ] || [ -z "${target_jsonl_file}" ]; then
    echo "Usage: $0 <local cloudwatch dir> <target jsonl file>"
    exit 1
fi

echo "converting ${local_cloudwatch_dir} to ${target_jsonl_file}"

find "${local_cloudwatch_dir}" -type 'f' \
    | grep -v jsonl \
    | xargs -n 1 ./scripts/convert-cloudwatch-logs-to-bigquery-jsonl.sh
(find "${local_cloudwatch_dir}" -type 'f' | grep jsonl | xargs cat) > "${target_jsonl_file}"
