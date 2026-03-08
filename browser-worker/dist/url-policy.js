import dns from "node:dns/promises";
import net from "node:net";
const METADATA_HOSTS = new Set(["169.254.169.254", "metadata.google.internal", "metadata.aws.internal"]);
export class UrlPolicy {
    allowedHosts;
    constructor(allowedHosts) {
        this.allowedHosts = allowedHosts;
    }
    async validate(input) {
        const url = new URL(input);
        if (!new Set(["http:", "https:"]).has(url.protocol))
            throw new Error("Only HTTP and HTTPS are allowed");
        const hostname = url.hostname.toLowerCase().replace(/\.$/, "");
        if (!this.allowedHosts.includes(hostname))
            throw new Error("Destination host is not allowlisted");
        if (hostname === "localhost" || METADATA_HOSTS.has(hostname))
            throw new Error("Destination is blocked");
        const addresses = net.isIP(hostname) ? [{ address: hostname }] : await dns.lookup(hostname, { all: true, verbatim: true });
        if (addresses.length === 0 || addresses.some(({ address }) => isBlockedAddress(address))) {
            throw new Error("Destination resolves to a private or special-use address");
        }
        return url;
    }
}
export function isBlockedAddress(address) {
    if (net.isIPv4(address)) {
        const [a = 0, b = 0] = address.split(".").map(Number);
        return (a === 0 || a === 10 || a === 127 ||
            (a === 100 && b >= 64 && b <= 127) ||
            (a === 169 && b === 254) ||
            (a === 172 && b >= 16 && b <= 31) ||
            (a === 192 && b === 168) ||
            a >= 224);
    }
    if (net.isIPv6(address)) {
        const normalized = address.toLowerCase();
        return normalized === "::" || normalized === "::1" || normalized.startsWith("fc") ||
            normalized.startsWith("fd") || normalized.startsWith("fe8") || normalized.startsWith("fe9") ||
            normalized.startsWith("fea") || normalized.startsWith("feb") || normalized.startsWith("::ffff:127.");
    }
    return true;
}
