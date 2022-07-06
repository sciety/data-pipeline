#!/bin/bash

set -euo pipefail

log_gz_file="$1"
common_filename=${log_gz_file%.*}
target_jsonl_gz_file="$common_filename.jsonl.gz"

echo "converting $log_gz_file to $target_jsonl_gz_file"

cat $log_gz_file \
    | zcat \
    | sed -e 's/[^ ]* //' \
    | jq --compact-output 'del(.kubernetes) | del(.docker)' \
    | gzip - \
    > $target_jsonl_gz_file
