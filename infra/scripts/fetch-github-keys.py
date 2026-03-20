#!/usr/bin/env python3
"""
Fetch SSH keys from GitHub API for multiple users.
Uses GitHub PAT for authenticated requests to avoid rate limiting.
"""

import sys
import json
import os
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

def fetch_github_keys(username, github_pat=None):
    """
    Fetch SSH keys for a GitHub user via API.

    Args:
        username: GitHub username
        github_pat: GitHub Personal Access Token (optional but recommended)

    Returns:
        List of SSH public keys or None if failed
    """
    url = f"https://api.github.com/users/{username}/keys"
    headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'dra-lab-provisioner'
    }

    if github_pat:
        headers['Authorization'] = f'token {github_pat}'

    try:
        req = Request(url, headers=headers)
        with urlopen(req) as response:
            data = json.loads(response.read().decode())
            return [key['key'] for key in data]
    except HTTPError as e:
        print(f"Error fetching keys for {username}: HTTP {e.code}", file=sys.stderr)
        return None
    except URLError as e:
        print(f"Error fetching keys for {username}: {e.reason}", file=sys.stderr)
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: fetch-github-keys.py <username> [<username> ...]", file=sys.stderr)
        print("", file=sys.stderr)
        print("Set GITHUB_PAT environment variable to use authenticated requests.", file=sys.stderr)
        sys.exit(1)

    github_pat = os.environ.get('GITHUB_PAT')
    if not github_pat:
        print("Warning: GITHUB_PAT not set. Using unauthenticated requests (lower rate limit).", file=sys.stderr)

    results = {}
    for username in sys.argv[1:]:
        keys = fetch_github_keys(username, github_pat)
        if keys:
            results[username] = keys
        else:
            results[username] = []

    print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()
