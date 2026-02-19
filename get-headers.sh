#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <http(s)://url>"
}

[[ $# -ge 1 ]] || { usage; exit 1; }
url="$1"

if [[ ! "$url" =~ ^https?:// ]]; then
  echo "Error: URL must start with http:// or https://"
  exit 1
fi

curl -sS -I -L --max-time 15 "$url"
