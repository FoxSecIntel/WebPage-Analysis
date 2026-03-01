#!/bin/bash
set -euo pipefail

__r17q_blob="wqhWaWN0b3J5IGlzIG5vdCB3aW5uaW5nIGZvciBvdXJzZWx2ZXMsIGJ1dCBmb3Igb3RoZXJzLiAtIFRoZSBNYW5kYWxvcmlhbsKoCg=="
if [[ "${1:-}" == "m" || "${1:-}" == "-m" ]]; then
  echo "$__r17q_blob" | base64 --decode
  exit 0
fi


usage() {
  cat <<'EOF'
Usage:
  HREF-Link-Extractor.sh [options] <http(s)://url>

Options:
  --absolute-only        Output only absolute URLs (default behavior)
  --include-relative     Also output unresolved relative links
  --include-special      Include mailto:, javascript:, tel:, and fragment-only links
  --domain-only          Output domains only (deduped)
  --output text|json     Output format (default: text)
  --timeout <seconds>    Curl timeout in seconds (default: 20)
  --retries <n>          Curl retry count (default: 1)
  -h, --help             Show help
EOF
}

include_relative=false
include_special=false
absolute_only=true
domain_only=false
output_format="text"
timeout_s=20
retries=1

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --absolute-only) absolute_only=true; include_relative=false; shift ;;
    --include-relative) include_relative=true; absolute_only=false; shift ;;
    --include-special) include_special=true; shift ;;
    --domain-only) domain_only=true; shift ;;
    --output)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --output"; exit 1; }
      output_format="$1"
      [[ "$output_format" =~ ^(text|json)$ ]] || { echo "--output must be text or json"; exit 1; }
      shift
      ;;
    --timeout)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --timeout"; exit 1; }
      timeout_s="$1"
      [[ "$timeout_s" =~ ^[0-9]+$ ]] || { echo "--timeout must be numeric"; exit 1; }
      shift
      ;;
    --retries)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --retries"; exit 1; }
      retries="$1"
      [[ "$retries" =~ ^[0-9]+$ ]] || { echo "--retries must be numeric"; exit 1; }
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done

[[ ${#args[@]} -ge 1 ]] || { usage; exit 1; }
base_url="${args[0]}"
[[ "$base_url" =~ ^https?:// ]] || { echo "Error: URL must start with http:// or https://"; exit 1; }

content="$(curl -sS -L --max-time "$timeout_s" --retry "$retries" "$base_url" || true)"
[[ -n "$content" ]] || { echo "Unable to retrieve content from $base_url"; exit 1; }

mapfile -t raw_links < <(printf '%s' "$content" | grep -Eoi 'href=["'"'"'][^"'"'"']+["'"'"']' | sed -E 's/^href=["'"'"'](.*)["'"'"']$/\1/')

total_found=${#raw_links[@]}

declare -A seen_links
external_count=0
same_domain_count=0

base_host="$(printf '%s' "$base_url" | sed -E 's#^https?://([^/]+).*$#\1#')"

resolve_url() {
  local base="$1"
  local link="$2"
  python3 - <<'PY' "$base" "$link"
import sys
from urllib.parse import urljoin
print(urljoin(sys.argv[1], sys.argv[2]))
PY
}

is_special() {
  local link="$1"
  [[ "$link" =~ ^(mailto:|javascript:|tel:|#) ]]
}

for link in "${raw_links[@]}"; do
  [[ -n "$link" ]] || continue

  if is_special "$link"; then
    $include_special || continue
    seen_links["$link"]=1
    continue
  fi

  final="$link"
  if [[ "$link" =~ ^https?:// ]]; then
    :
  elif [[ "$link" =~ ^// ]]; then
    final="https:${link}"
  elif $include_relative; then
    seen_links["$link"]=1
    final="$(resolve_url "$base_url" "$link")"
  else
    final="$(resolve_url "$base_url" "$link")"
  fi

  if [[ "$final" =~ ^https?:// ]]; then
    seen_links["$final"]=1
    host="$(printf '%s' "$final" | sed -E 's#^https?://([^/]+).*$#\1#')"
    if [[ "$host" == "$base_host" ]]; then
      ((same_domain_count+=1)) || true
    else
      ((external_count+=1)) || true
    fi
  fi
done

# Prepare output set
declare -a output_items=()
if $domain_only; then
  declare -A domains=()
  for link in "${!seen_links[@]}"; do
    if [[ "$link" =~ ^https?:// ]]; then
      d="$(printf '%s' "$link" | sed -E 's#^https?://([^/]+).*$#\1#')"
      [[ -n "$d" ]] && domains["$d"]=1
    fi
  done
  mapfile -t output_items < <(printf '%s\n' "${!domains[@]}" | sort)
else
  mapfile -t output_items < <(printf '%s\n' "${!seen_links[@]}" | sort)
fi

unique_count=${#output_items[@]}

if [[ "$output_format" == "json" ]]; then
  printf '%s\n' "${output_items[@]}" | jq -R . | jq -s \
    --arg base_url "$base_url" \
    --argjson total_found "$total_found" \
    --argjson unique_count "$unique_count" \
    --argjson external_count "$external_count" \
    --argjson same_domain_count "$same_domain_count" \
    '{
      base_url: $base_url,
      total_href_found: $total_found,
      unique_output_count: $unique_count,
      external_link_count: $external_count,
      same_domain_link_count: $same_domain_count,
      items: .
    }'
else
  printf '%s\n' "${output_items[@]}"
  echo
  echo "Summary: total_hrefs=${total_found} unique_output=${unique_count} external=${external_count} same_domain=${same_domain_count}"
fi
