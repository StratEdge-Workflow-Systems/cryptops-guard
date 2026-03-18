# Security Policy & Vulnerability Disclosure

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.4.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Deterministic Fail-Closed Guarantee

All StratEdge control-plane packages (`@stratedge/remitbot-mcp`, `@stratedge/guardroute-sdk`, `@stratedge/proofaudit-verify`, `@stratedge/cryptops-guard`, and `@stratedge/audit-check`) operate on a strict **fail-closed** principle with zero runtime external network dependencies in the core verification path.

## Reporting a Vulnerability

Please report security issues privately to `security@stratedgeworkflow.com`. Do not open public GitHub issues for undisclosed vulnerabilities.
