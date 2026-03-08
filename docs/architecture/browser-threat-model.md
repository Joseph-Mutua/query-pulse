# Browser diagnostics threat model

The worker treats every submitted URL and response as hostile. Primary risks are SSRF into loopback/private/link-local/metadata networks, DNS rebinding, redirect pivots, unbounded downloads, malicious scripts, and sensitive artifact retention.

Controls implemented in `UrlPolicy` and `DiagnosticRunner`:

- exact provider-host allowlist;
- HTTP(S)-only URLs;
- DNS resolution before navigation and again for every request/redirect;
- IPv4 loopback, RFC1918, carrier-grade NAT, link-local, multicast/reserved and metadata blocks;
- IPv6 loopback, unspecified, unique-local, and link-local blocks;
- 15-second navigation timeout, 16 KB request body, 50 network-error cap, and per-run artifact directory;
- challenge detection and classification without solving or evasion.

Residual risks include TOCTOU DNS rebinding between validation and connection, browser vulnerabilities, provider pages loading non-allowlisted CDN assets, disk growth, and sensitive page content in artifacts. Production deployment should add an egress firewall, run as non-root with a read-only filesystem except the artifact volume, cap artifact retention, encrypt storage, authenticate Rails-to-worker calls, and pin/update the browser image.
