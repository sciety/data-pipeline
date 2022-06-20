#!/bin/bash

set -euo pipefail

cat $1 \
    | sed -e 's/[^ ]* //' \
    | jq --compact-output 'del(.kubernetes) | del(.docker)' \
    | gzip - \
    > $1.jsonl.gz
