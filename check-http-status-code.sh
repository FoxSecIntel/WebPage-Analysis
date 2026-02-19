#!/bin/bash
set -euo pipefail

usage(){ echo "Usage: $0 <status_code>"; }

[[ $# -ge 1 ]] || { usage; exit 1; }
status_code="$1"
[[ "$status_code" =~ ^[0-9]{3}$ ]] || { echo "Invalid status code"; exit 1; }

case "$status_code" in
  100) msg="Continue";; 101) msg="Switching Protocols";;
  200) msg="OK";; 201) msg="Created";; 202) msg="Accepted";; 203) msg="Non-Authoritative Information";; 204) msg="No Content";; 205) msg="Reset Content";; 206) msg="Partial Content";;
  300) msg="Multiple Choices";; 301) msg="Moved Permanently";; 302) msg="Found";; 303) msg="See Other";; 304) msg="Not Modified";; 307) msg="Temporary Redirect";; 308) msg="Permanent Redirect";;
  400) msg="Bad Request";; 401) msg="Unauthorized";; 402) msg="Payment Required";; 403) msg="Forbidden";; 404) msg="Not Found";; 405) msg="Method Not Allowed";; 406) msg="Not Acceptable";; 407) msg="Proxy Authentication Required";; 408) msg="Request Timeout";; 409) msg="Conflict";; 410) msg="Gone";; 411) msg="Length Required";; 412) msg="Precondition Failed";; 413) msg="Payload Too Large";; 414) msg="URI Too Long";; 415) msg="Unsupported Media Type";; 416) msg="Range Not Satisfiable";; 417) msg="Expectation Failed";; 429) msg="Too Many Requests";;
  500) msg="Internal Server Error";; 501) msg="Not Implemented";; 502) msg="Bad Gateway";; 503) msg="Service Unavailable";; 504) msg="Gateway Timeout";; 505) msg="HTTP Version Not Supported";;
  *) msg="Unknown/unsupported status code";;
esac

echo "$status_code $msg"

if (( status_code >= 100 && status_code < 200 )); then echo "Class: 1xx Informational"
elif (( status_code >= 200 && status_code < 300 )); then echo "Class: 2xx Success"
elif (( status_code >= 300 && status_code < 400 )); then echo "Class: 3xx Redirection"
elif (( status_code >= 400 && status_code < 500 )); then echo "Class: 4xx Client Error"
elif (( status_code >= 500 && status_code < 600 )); then echo "Class: 5xx Server Error"
fi
