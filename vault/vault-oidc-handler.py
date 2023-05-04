#!/usr/bin/env python
import argparse
import html
import os
import re
import sys
import urllib
from pathlib import Path
from requests import Request, Session
from getpass import getpass


def prompt() -> dict:
    user = str(input(f'Anais login (default: {os.environ["USER"]}): ') or os.environ["USER"])
    passwd = str(getpass(prompt='Password: '))
    print(f"[INFO] Authenticating as: {user}")
    return {
        'username': user,
        'password': passwd
    }


def read_oidc_out(logfile: str) -> str:
    log = Path(logfile).read_text()
    if "Error" in log:
        raise ValueError(f"[FATAL] {log}\n")
    # https://regex101.com/r/041IAO/1
    regex = r"\s*(?P<vault_auth_url>https://.*)\s*"
    matches = re.search(regex, log)
    if matches is None:
        raise ValueError(f"[FATAL] Vault URL pattern not matched while reading log {log}\n")
    return matches.group('vault_auth_url')


def oidc_keycloak_submit(vault_auth_url: str, form: dict) -> int:
    # Decode URL
    vault_auth_url = urllib.parse.unquote(vault_auth_url)

    # Start Keycloak transactions
    session = Session()
    # Set this to False for debugging.
    session.verify = "/etc/ssl/certs/ca-bundle.crt"

    # Probe keycloak
    keycloak_auth_url_response = session.get(
        vault_auth_url
    )
    if keycloak_auth_url_response.status_code != 200:
        return 1

    # Extract metadata fields
    # https://regex101.com/r/iPXnI8/1
    regex = r"id=\"kc-form-login\".*action=\"(?P<kc_auth_url>.*)\"\s"
    matches = re.search(regex, keycloak_auth_url_response.text)
    kc_auth_url = matches.group('kc_auth_url')
    kc_auth_url = html.unescape(kc_auth_url)

    # Submit form to Keycloak
    kc_token_req = Request(
        'POST',
        kc_auth_url,
        data={
            'username':         form['username'],
            'password':         form['password'],
            'rememberMe':       'on',
            'credentialId':     ''
        }
    )
    # Prepare Keycloak
    kc_token_prepped = session.prepare_request(kc_token_req)

    keycloak_token_response = session.send(
        kc_token_prepped,
        allow_redirects=False
    )

    # Inspect redirection
    if keycloak_token_response.status_code != 302:
        sys.stderr.write("[WARN] La connexion a échoué. Utilisateur ou mot de passe invalide.\n")
        return 1

    # We are expecting to be redirected to localhost
    if "://localhost" not in str(keycloak_token_response.next.url):
        sys.stderr.write("[WARN] La connexion a échoué. La session a expiré.\n")
        return 1

    print(f"[INFO] L'authentification est réussie, redirection vers {str(keycloak_token_response.next.url)}...")
    session.send(
        keycloak_token_response.next
    )
    return 0


def main(arguments: argparse.Namespace) -> int:
    print(f"[INFO] Starting Vault OIDC client (using {arguments.logfile})")
    err_code = 1

    try:
        vault_auth_url = read_oidc_out(arguments.logfile)
        err_code = oidc_keycloak_submit(
            vault_auth_url,
            prompt()
        )
    except ValueError as ve:
        sys.stderr.write(str(ve))

    print(f"[INFO] Exiting Vault OIDC client ({err_code})")
    return err_code


if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument("logfile", help="nohup output file", type=str)

    sys.exit(
        main(parser.parse_args())
    )
