import dns from "node:dns/promises";
import net from "node:net";

const METADATA_HOSTS = new Set([
  "169.254.169.254",
  "metadata.google.internal",
  "metadata.aws.internal",
]);

export class UrlPolicy {
  constructor(private readonly allowedHosts: string[]) {}

  async validate(input: string): Promise<URL> {
    const url = new URL(input);
    if (!new Set(["http:", "https:"]).has(url.protocol))
      throw new Error("Only HTTP and HTTPS are allowed");
    const hostname = url.hostname.toLowerCase().replace(/\.$/, "");
    if (!this.allowedHosts.includes(hostname))
      throw new Error("Destination host is not allowlisted");
    if (hostname === "localhost" || METADATA_HOSTS.has(hostname))
      throw new Error("Destination is blocked");

    const addresses = net.isIP(hostname)
      ? [{ address: hostname }]
      : await dns.lookup(hostname, { all: true, verbatim: true });
    if (
      addresses.length === 0 ||
      addresses.some(({ address }) => isBlockedAddress(address))
    ) {
      throw new Error(
        "Destination resolves to a private or special-use address",
      );
    }
    return url;
  }
}

export function isBlockedAddress(address: string): boolean {
  if (net.isIPv4(address)) {
    const [a = 0, b = 0, c = 0] = address.split(".").map(Number);
    return (
      a === 0 ||
      a === 10 ||
      a === 127 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 0 && c === 0) ||
      (a === 192 && b === 0 && c === 2) ||
      (a === 192 && b === 168) ||
      (a === 198 && (b === 18 || b === 19)) ||
      (a === 198 && b === 51 && c === 100) ||
      (a === 203 && b === 0 && c === 113) ||
      a >= 224
    );
  }
  if (net.isIPv6(address)) {
    const normalized = address.toLowerCase();
    const globalUnicast = /^[23]/.test(normalized);
    return (
      !globalUnicast ||
      normalized.startsWith("2001:0:") ||
      normalized.startsWith("2001:2:") ||
      normalized.startsWith("2001:10:") ||
      normalized.startsWith("2001:20:") ||
      normalized.startsWith("2001:db8:") ||
      normalized.startsWith("2002:")
    );
  }
  return true;
}
