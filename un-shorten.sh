#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  un-shorten.sh [options] <url>
  un-shorten.sh [options] -f <urls.txt>

Options:
  -f FILE           Batch mode: resolve one URL per line
  --chain           Show redirect chain
  --json            JSON output
  --timeout SEC     Request timeout in seconds (default: 15)
  --retries N       Retry count (default: 1)
  -h, --help        Show help
EOF
}

show_chain=false
json_output=false
timeout_s=15
retries=1
batch_file=""

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --chain) show_chain=true; shift ;;
    --json) json_output=true; shift ;;
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
    -f)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for -f"; exit 1; }
      batch_file="$1"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done

validate_url() {
  local u="$1"
  [[ "$u" =~ ^https?:// ]]
}

resolve_one() {
  local url="$1"

  if ! validate_url "$url"; then
    if $json_output; then
      jq -n --arg input "$url" --arg err "invalid_url" '{input:$input,error:$err}'
    else
      echo "Error: URL must start with http:// or https:// -> $url"
    fi
    return 1
  fi

  local headers status final_url final_domain final_ip err=""

  headers="$(curl -sS -L -I --max-time "$timeout_s" --retry "$retries" "$url" 2>/dev/null || true)"
  final_url="$(curl -sS -L -o /dev/null -w '%{url_effective}' --max-time "$timeout_s" --retry "$retries" "$url" 2>/dev/null || true)"

  if [[ -z "$final_url" ]]; then
    err="resolve_failed"
    if $json_output; then
      jq -n --arg input "$url" --arg err "$err" '{input:$input,error:$err}'
    else
      echo "Error: Unable to resolve URL -> $url"
    fi
    return 1
  fi

  status="$(printf '%s\n' "$headers" | awk 'toupper($1)=="HTTP/1.1" || toupper($1)=="HTTP/2" {code=$2} END{print code}')"
  final_domain="$(printf '%s' "$final_url" | sed -E 's#^https?://([^/:]+).*$#\1#')"
  final_ip="$(getent ahostsv4 "$final_domain" 2>/dev/null | awk '{print $1; exit}')"

  if $json_output; then
    if $show_chain; then
      mapfile -t chain < <(printf '%s\n' "$headers" | awk 'tolower($1)=="location:" {print $2}' | tr -d '\r')
      printf '%s\n' "${chain[@]}" | jq -R . | jq -s \
        --arg input "$url" \
        --arg final_url "$final_url" \
        --arg status "$status" \
        --arg final_domain "$final_domain" \
        --arg final_ip "${final_ip:-}" \
        '{input:$input,final_url:$final_url,status_code:$status,final_domain:$final_domain,final_ip:$final_ip,redirect_chain:.}'
    else
      jq -n \
        --arg input "$url" \
        --arg final_url "$final_url" \
        --arg status "$status" \
        --arg final_domain "$final_domain" \
        --arg final_ip "${final_ip:-}" \
        '{input:$input,final_url:$final_url,status_code:$status,final_domain:$final_domain,final_ip:$final_ip}'
    fi
  else
    echo "Input URL:   $url"
    echo "Final URL:   $final_url"
    echo "Status code: ${status:-unknown}"
    echo "Final domain:${final_domain}"
    echo "Final IP:    ${final_ip:-unknown}"
    if $show_chain; then
      echo "Redirect chain:"
      printf '%s\n' "$headers" | awk 'tolower($1)=="location:" {print "  - " $2}' | tr -d '\r'
    fi
  fi
}

if [[ -n "$batch_file" ]]; then
  [[ -f "$batch_file" ]] || { echo "Error: batch file not found: $batch_file"; exit 1; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    resolve_one "$line" || true
    $json_output || echo
  done < "$batch_file"
  exit 0
fi

[[ ${#args[@]} -ge 1 ]] || { usage; exit 1; }
resolve_one "${args[0]}"
