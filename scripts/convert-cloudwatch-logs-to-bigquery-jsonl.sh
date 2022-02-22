#!/bin/bash

set -euo pipefail

cat $1 \
    | sed -e 's/[^ ]* //' \
    | jq --compact-output 'del(.kubernetes) | del(.docker)' \
    > $1.jsonl
