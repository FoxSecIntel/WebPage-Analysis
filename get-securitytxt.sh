#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  get-securitytxt.sh <domain>
  get-securitytxt.sh -i

Options:
  -i  Explain what security.txt is
EOF
}

if [[ "${1:-}" == "-i" ]]; then
  echo "security.txt provides vulnerability disclosure contact/policy information. See https://securitytxt.org/"
  exit 0
fi

[[ $# -ge 1 ]] || { usage; exit 1; }
domain="$1"

if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
  echo "Invalid domain name"
  exit 1
fi

fetch() {
  local u="$1"
  curl -sS -L --max-time 15 "$u" || true
}

root_url="https://${domain}/security.txt"
wk_url="https://${domain}/.well-known/security.txt"

root_txt="$(fetch "$root_url")"
wk_txt="$(fetch "$wk_url")"

if [[ -z "$root_txt" && -z "$wk_txt" ]]; then
  root_url="https://www.${domain}/security.txt"
  wk_url="https://www.${domain}/.well-known/security.txt"
  root_txt="$(fetch "$root_url")"
  wk_txt="$(fetch "$wk_url")"
fi

echo "$root_url:"
if [[ -n "$root_txt" ]]; then
  echo "$root_txt"
else
  echo "(not found)"
fi

echo
echo "$wk_url:"
if [[ -n "$wk_txt" ]]; then
  echo "$wk_txt"
else
  echo "(not found)"
fi

echo
parse_fields() {
  local txt="$1"
  [[ -z "$txt" ]] && return 0
  echo "$txt" | grep -E '^(Contact|Expires|Policy|Hiring|Acknowledgments|Preferred-Languages|Canonical|Encryption):' || true
}

echo "Parsed fields:"
parse_fields "$root_txt"
parse_fields "$wk_txt"
