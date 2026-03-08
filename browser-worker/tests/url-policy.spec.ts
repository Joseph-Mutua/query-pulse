import { expect, test } from "@playwright/test";
import { isBlockedAddress } from "../src/url-policy.js";

test("blocks loopback and private IPv4 networks", () => {
  for (const address of [
    "127.0.0.1",
    "10.4.3.2",
    "172.16.0.1",
    "192.168.1.1",
    "169.254.169.254",
  ]) {
    expect(isBlockedAddress(address)).toBe(true);
  }
  expect(isBlockedAddress("8.8.8.8")).toBe(false);
});

test("blocks local and unique-local IPv6 networks", () => {
  expect(isBlockedAddress("::1")).toBe(true);
  expect(isBlockedAddress("fd00::1")).toBe(true);
  expect(isBlockedAddress("fe80::1")).toBe(true);
  expect(isBlockedAddress("2606:4700:4700::1111")).toBe(false);
});

test("blocks documentation, benchmark, and IPv4-mapped address space", () => {
  for (const address of [
    "192.0.2.10",
    "198.18.0.1",
    "198.51.100.20",
    "203.0.113.30",
    "2001:db8::1",
    "::ffff:10.0.0.1",
  ]) {
    expect(isBlockedAddress(address), address).toBe(true);
  }
});
