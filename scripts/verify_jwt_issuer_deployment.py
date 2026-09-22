#!/usr/bin/env python3
"""Verify the shared JWT issuer configuration with an optional real-token probe."""

import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request

ISSUER_PATH = ("spring", "security", "oauth2", "resourceserver", "jwt", "issuer-uri")


def jwt_issuer(token: str) -> str:
    parts = token.strip().split(".")
    if len(parts) != 3:
        raise ValueError("stdin does not contain a JWT")
    payload = parts[1] + "=" * (-len(parts[1]) % 4)
    issuer = json.loads(base64.urlsafe_b64decode(payload)).get("iss")
    if not issuer:
        raise ValueError("JWT does not contain an iss claim")
    return issuer


def shared_issuer(content: str) -> str:
    stack = []
    for raw_line in content.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        match = re.match(r"^(\s*)([^:#]+):(?:\s*(.*))?$", raw_line)
        if not match:
            continue
        indent = len(match.group(1))
        key = match.group(2).strip()
        value = (match.group(3) or "").strip()
        while stack and stack[-1][0] >= indent:
            stack.pop()
        path = tuple(item[1] for item in stack) + (key,)
        if path == ISSUER_PATH:
            if not value:
                raise ValueError("shared issuer-uri is empty")
            placeholder = re.fullmatch(r"\$\{([^:}]+):([^}]+)\}", value)
            return os.environ.get(placeholder.group(1), placeholder.group(2)) if placeholder else value
        if not value:
            stack.append((indent, key))
    raise ValueError("shared config does not contain spring.security.oauth2.resourceserver.jwt.issuer-uri")


def load_config(path: str, url: str | None) -> str:
    if url:
        with urllib.request.urlopen(url, timeout=10) as response:
            return response.read().decode()
    with open(path, encoding="utf-8") as config_file:
        return config_file.read()


def request_current_user(url: str, token: str) -> None:
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            if response.status != 200:
                raise RuntimeError(f"current-user verification returned HTTP {response.status}")
    except urllib.error.HTTPError as error:
        challenge = error.headers.get("WWW-Authenticate", "")
        raise RuntimeError(
            f"current-user verification returned HTTP {error.code}; WWW-Authenticate={challenge}"
        ) from error


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-file", default="config/nacos/opensabre-common.yml")
    parser.add_argument("--config-url")
    parser.add_argument("--current-user-url")
    parser.add_argument("--token-stdin", action="store_true")
    args = parser.parse_args()

    configured = shared_issuer(load_config(args.config_file, args.config_url))
    if args.token_stdin:
        if not args.current_user_url:
            parser.error("--current-user-url is required with --token-stdin")
        token = sys.stdin.read().strip()
        issued = jwt_issuer(token)
        if issued != configured:
            raise RuntimeError(f"issuer mismatch: JWT={issued!r}, shared config={configured!r}")
        request_current_user(args.current_user_url, token)

    print(f"Shared JWT issuer verified: {configured}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, urllib.error.URLError) as error:
        print(f"JWT issuer deployment verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
