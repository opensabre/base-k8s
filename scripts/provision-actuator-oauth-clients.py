#!/usr/bin/env python3
"""Provision two least-privilege OAuth clients without placing secrets in Git.

Run on the deployment host, where the MySQL container and Python bcrypt module
already exist. The script never prints secrets or password hashes.
"""

import json
import os
import pathlib
import secrets
import subprocess

import bcrypt


ROOT = pathlib.Path(__file__).resolve().parents[1]
SECRET_DIR = ROOT / "secrets"
CLIENTS = (
    ("opensabre-prometheus", "prometheus-oauth-client-secret"),
    ("opensabre-actuator-control-plane", "gateway-admin-actuator-oauth.env"),
)


def mysql(sql: str) -> str:
    result = subprocess.run(
        ["docker", "exec", "-i", "mysql", "sh", "-c",
         'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -B os_base_auth'],
        input=sql,
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


def provision(client_id: str, filename: str) -> None:
    path = SECRET_DIR / filename
    count = mysql(
        "SELECT COUNT(*) FROM oauth2_registered_client "
        f"WHERE client_id = '{client_id}' AND deleted = 'N';"
    )
    if count != "0":
        if not path.is_file():
            raise RuntimeError(f"{client_id} exists, but {path} is missing")
        print(f"{client_id}: already provisioned")
        return
    if path.exists():
        raise RuntimeError(f"{path} exists without a client record; inspect before retrying")

    secret = secrets.token_urlsafe(48)
    password_hash = bcrypt.hashpw(secret.encode(), bcrypt.gensalt(rounds=12)).decode()
    if client_id == "opensabre-prometheus":
        contents = secret
    else:
        contents = (
            f"ACTUATOR_OAUTH_CLIENT_ID={client_id}\n"
            f"ACTUATOR_OAUTH_CLIENT_SECRET={secret}\n"
        )
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(contents)

    client_settings = json.dumps({
        "settings.client.require-proof-key": False,
        "settings.client.require-authorization-consent": False,
    }, separators=(",", ":"))
    token_settings = json.dumps({
        "settings.token.access-token-time-to-live": 300,
        "settings.token.access-token-format": {"value": "self-contained"},
        "settings.token.refresh-token-time-to-live": 3600,
        "settings.token.reuse-refresh-tokens": True,
        "settings.token.id-token-signature-algorithm": "RS256",
    }, separators=(",", ":"))
    sql = f"""
        INSERT INTO oauth2_registered_client (
            id, client_id, client_id_issued_at, client_secret,
            client_secret_expires_at, client_name,
            client_authentication_methods, authorization_grant_types,
            redirect_uris, post_logout_redirect_uris, scopes,
            client_settings, token_settings, deleted,
            created_time, updated_time, created_by, updated_by
        ) VALUES (
            '{client_id}', '{client_id}', NOW(3), '{password_hash}',
            DATE_ADD(NOW(3), INTERVAL 365 DAY), '{client_id}',
            'client_secret_basic', 'client_credentials',
            '', '', 'actuator.read',
            '{client_settings}', '{token_settings}', 'N',
            NOW(3), NOW(3), 'deployment', 'deployment'
        );
    """
    mysql(sql)
    print(f"{client_id}: created")


def main() -> None:
    os.umask(0o077)
    SECRET_DIR.mkdir(mode=0o700, exist_ok=True)
    SECRET_DIR.chmod(0o700)
    for client_id, filename in CLIENTS:
        provision(client_id, filename)
    prometheus_secret = SECRET_DIR / "prometheus-oauth-client-secret"
    os.chown(prometheus_secret, 0, 65534)
    os.chmod(prometheus_secret, 0o640)


if __name__ == "__main__":
    main()
