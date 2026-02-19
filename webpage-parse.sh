#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <http(s)://url>"
}

[[ $# -ge 1 ]] || { usage; exit 1; }
url="$1"
[[ "$url" =~ ^https?:// ]] || { echo "Error: URL must start with http:// or https://"; exit 1; }

html="$(curl -sS -L --max-time 20 "$url" || true)"
[[ -n "$html" ]] || { echo "Unable to retrieve content from $url"; exit 1; }

echo "Links (domains found in absolute URLs):"
printf '%s' "$html" | grep -Eoi 'https?://[^"'"'"'<> ]+' | sed 's/[),.;]$//' | sed -E 's#https?://([^/]+)/?.*#\1#' | sort -u

echo
echo "Email addresses:"
printf '%s' "$html" | grep -Eoi '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' | sort -u
