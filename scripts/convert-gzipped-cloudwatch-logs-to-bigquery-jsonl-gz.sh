#!/bin/bash

set -euo pipefail

log_gz_file="$1"

zcat $log_gz_file \
    | sed -e 's/[^ ]* //' \
    | jq --compact-output 'del(.kubernetes) | del(.docker)' \
    | gzip - \
    > $(dirname "$log_gz_file")/$(basename "$log_gz_file" .gz).jsonl.gz
