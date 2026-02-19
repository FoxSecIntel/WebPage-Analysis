# WebPage-Analysis

A practical Bash toolkit for quick webpage/URL triage in OSINT and defensive investigations.

## Tools

- `un-shorten.sh` — resolve redirects and reveal final URL
- `get-headers.sh` — fetch HTTP response headers
- `get-securitytxt.sh` — fetch and parse `security.txt`
- `webpage-parse.sh` — extract links/emails from webpage HTML
- `HREF-Link-Extractor.sh` — extract normalized href links
- `check-http-status-code.sh` — explain HTTP status codes
- `qa_check.sh` — syntax + shellcheck validation

## Usage

```bash
./un-shorten.sh https://bit.ly/example
./get-headers.sh https://example.com
./get-securitytxt.sh example.com
./webpage-parse.sh https://example.com
./HREF-Link-Extractor.sh https://example.com
./HREF-Link-Extractor.sh --domain-only https://example.com
./HREF-Link-Extractor.sh --output json --include-relative https://example.com
./check-http-status-code.sh 404
./qa_check.sh
```

## Notes

- Scripts are read-only and intended for authorized defensive/OSINT use.
- Network timeouts and temporary web errors are handled where possible.
- For reproducible output in pipelines, prefer `--no-color` where supported.
