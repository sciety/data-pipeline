#!/bin/bash

set -euo pipefail

logs_url="$1"
target_dir="$2"

if [ -z "${logs_url}" ] || [ -z "${target_dir}" ]; then
    echo "Usage: $0 <logs url> <target dir>"
    exit 1
fi

echo "downloading from ${logs_url} to ${target_dir}"

mkdir -p "${target_dir}"
aws s3 cp --recursive ${logs_url} "${target_dir}"
