#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <https://short.url>"
}

[[ $# -ge 1 ]] || { usage; exit 1; }
url="$1"

if [[ ! "$url" =~ ^https?:// ]]; then
  echo "Error: URL must start with http:// or https://"
  exit 1
fi

final_url="$(curl -sS -L -o /dev/null -w '%{url_effective}' --max-time 15 "$url" || true)"

if [[ -z "$final_url" ]]; then
  echo "Error: Unable to resolve URL"
  exit 1
fi

echo "$final_url"
