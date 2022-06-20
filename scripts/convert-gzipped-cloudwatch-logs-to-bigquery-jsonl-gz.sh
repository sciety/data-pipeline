#!/bin/bash

set -euo pipefail

log_gz_file="$1"
common_filename=$(dirname "$log_gz_file")/$(basename "$log_gz_file" .gz)
target_jsonl_gz_file="$common_filename.jsonl.gz"

zcat $log_gz_file \
    | sed -e 's/[^ ]* //' \
    | jq --compact-output 'del(.kubernetes) | del(.docker)' \
    | gzip - \
    > $target_jsonl_gz_file
