#!/bin/bash

set -euo pipefail

zcat $1 \
    | sed -e 's/[^ ]* //' \
    | jq --compact-output 'del(.kubernetes) | del(.docker)' \
    | gzip - \
    > $(dirname "$1")/$(basename "$1" .gz).jsonl.gz
