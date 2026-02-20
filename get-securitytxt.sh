#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  get-securitytxt.sh [options] <domain>
  get-securitytxt.sh -i

Options:
  -i            Explain what security.txt is
  --json        Output JSON
  --strict      Exit non-zero when required fields are missing/invalid
  --timeout N   Timeout seconds (default: 15)
EOF
}

explain=false
json_output=false
strict=false
timeout_s=15

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) explain=true; shift ;;
    --json) json_output=true; shift ;;
    --strict) strict=true; shift ;;
    --timeout)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --timeout"; exit 1; }
      timeout_s="$1"
      [[ "$timeout_s" =~ ^[0-9]+$ ]] || { echo "--timeout must be numeric"; exit 1; }
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done

if $explain; then
  echo "security.txt provides vulnerability disclosure contact/policy information. See https://securitytxt.org/"
  exit 0
fi

[[ ${#args[@]} -ge 1 ]] || { usage; exit 1; }
domain="${args[0]}"

if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
  echo "Invalid domain name"
  exit 1
fi

parse_fields() {
  local txt="$1"
  printf '%s\n' "$txt" | grep -E '^(Contact|Expires|Policy|Hiring|Acknowledgments|Preferred-Languages|Canonical|Encryption):' || true
}

fetch_body_and_type() {
  local u="$1"
  local headers body ctype
  headers="$(curl -sS -L -I --max-time "$timeout_s" "$u" 2>/dev/null || true)"
  body="$(curl -sS -L --max-time "$timeout_s" "$u" 2>/dev/null || true)"
  ctype="$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1)=="content-type" {print $2}' | tail -n1 | tr -d '\r')"
  printf '%s\n__CTYPE__:%s\n' "$body" "$ctype"
}

root_url="https://${domain}/security.txt"
wk_url="https://${domain}/.well-known/security.txt"

root_pack="$(fetch_body_and_type "$root_url")"
root_txt="${root_pack%__CTYPE__:*}"
root_ctype="${root_pack##*__CTYPE__:}"

wk_pack="$(fetch_body_and_type "$wk_url")"
wk_txt="${wk_pack%__CTYPE__:*}"
wk_ctype="${wk_pack##*__CTYPE__:}"

source_status="NOT_FOUND"
source_url=""
content=""
ctype=""

if [[ -n "$wk_txt" ]]; then
  source_status="FOUND_WELL_KNOWN"
  source_url="$wk_url"
  content="$wk_txt"
  ctype="$wk_ctype"
elif [[ -n "$root_txt" ]]; then
  source_status="FOUND_ROOT"
  source_url="$root_url"
  content="$root_txt"
  ctype="$root_ctype"
else
  root_url="https://www.${domain}/security.txt"
  wk_url="https://www.${domain}/.well-known/security.txt"

  root_pack="$(fetch_body_and_type "$root_url")"
  root_txt="${root_pack%__CTYPE__:*}"
  root_ctype="${root_pack##*__CTYPE__:}"

  wk_pack="$(fetch_body_and_type "$wk_url")"
  wk_txt="${wk_pack%__CTYPE__:*}"
  wk_ctype="${wk_pack##*__CTYPE__:}"

  if [[ -n "$wk_txt" ]]; then
    source_status="FOUND_WWW_FALLBACK_WELL_KNOWN"
    source_url="$wk_url"
    content="$wk_txt"
    ctype="$wk_ctype"
  elif [[ -n "$root_txt" ]]; then
    source_status="FOUND_WWW_FALLBACK_ROOT"
    source_url="$root_url"
    content="$root_txt"
    ctype="$root_ctype"
  fi
fi

fields="$(parse_fields "$content")"
contact_lines="$(printf '%s\n' "$fields" | grep '^Contact:' || true)"
expires_line="$(printf '%s\n' "$fields" | grep '^Expires:' | head -n1 || true)"

has_contact=false
contact_ok=false
if [[ -n "$contact_lines" ]]; then
  has_contact=true
  if printf '%s\n' "$contact_lines" | grep -Eq '^Contact:\s*(mailto:|https?://)'; then
    contact_ok=true
  fi
fi

expires_ok=true
expires_state="missing"
if [[ -n "$expires_line" ]]; then
  expires_val="${expires_line#Expires: }"
  if ts=$(date -d "$expires_val" +%s 2>/dev/null); then
    now=$(date +%s)
    if (( ts < now )); then
      expires_ok=false
      expires_state="expired"
    else
      expires_state="valid"
    fi
  else
    expires_ok=false
    expires_state="invalid"
  fi
fi

is_text_plain=true
if [[ -n "$ctype" && ! "$ctype" =~ text/plain ]]; then
  is_text_plain=false
fi

size_bytes=$(printf '%s' "$content" | wc -c)
too_large=false
if (( size_bytes > 50000 )); then
  too_large=true
fi

if $json_output; then
  jq -n \
    --arg domain "$domain" \
    --arg status "$source_status" \
    --arg source_url "$source_url" \
    --arg content_type "$ctype" \
    --arg parsed_fields "$fields" \
    --arg expires_state "$expires_state" \
    --argjson has_contact "$has_contact" \
    --argjson contact_ok "$contact_ok" \
    --argjson expires_ok "$expires_ok" \
    --argjson is_text_plain "$is_text_plain" \
    --argjson size_bytes "$size_bytes" \
    --argjson too_large "$too_large" \
    '{
      domain:$domain,
      status:$status,
      source_url:$source_url,
      content_type:$content_type,
      validations:{
        has_contact:$has_contact,
        contact_ok:$contact_ok,
        expires_ok:$expires_ok,
        expires_state:$expires_state,
        is_text_plain:$is_text_plain,
        too_large:$too_large,
        size_bytes:$size_bytes
      },
      parsed_fields: ($parsed_fields|split("\n")|map(select(length>0)))
    }'
else
  echo "Status: $source_status"
  echo "Source: ${source_url:-N/A}"
  echo "Content-Type: ${ctype:-unknown}"
  echo "Size: ${size_bytes} bytes"

  echo
  if [[ -n "$content" ]]; then
    echo "security.txt content:"
    echo "$content"
  else
    echo "security.txt content: (not found)"
  fi

  echo
  echo "Parsed fields:"
  if [[ -n "$fields" ]]; then
    echo "$fields"
  else
    echo "(none)"
  fi

  echo
  echo "Validation:"
  echo "- Contact present: $has_contact"
  echo "- Contact format ok (mailto/http): $contact_ok"
  echo "- Expires state: $expires_state"
  echo "- Content-Type text/plain: $is_text_plain"
  echo "- Too large (>50KB): $too_large"
fi

if $strict; then
  fail=false
  [[ "$source_status" == NOT_FOUND ]] && fail=true
  [[ "$has_contact" == false ]] && fail=true
  [[ "$contact_ok" == false ]] && fail=true
  [[ "$expires_ok" == false ]] && fail=true
  if $fail; then
    exit 2
  fi
fi
