#!/bin/bash

set -euo pipefail

local_cloudwatch_dir="$1"
target_jsonl_gz_file="$2"

if [ -z "${local_cloudwatch_dir}" ] || [ -z "${target_jsonl_gz_file}" ]; then
    echo "Usage: $0 <local cloudwatch dir> <target jsonl gz file>"
    exit 1
fi

echo "converting ${local_cloudwatch_dir} to ${target_jsonl_gz_file}"

find "${local_cloudwatch_dir}" -type 'f' \
    | grep -v jsonl \
    | xargs -n 1 ./scripts/convert-gzipped-cloudwatch-logs-to-bigquery-jsonl-gz.sh

echo "combining jsonl files to ${target_jsonl_gz_file}"
(find "${local_cloudwatch_dir}" -type 'f' | grep jsonl.gz | xargs zcat | gzip -) > "${target_jsonl_gz_file}"
