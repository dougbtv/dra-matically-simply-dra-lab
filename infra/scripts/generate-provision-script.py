#!/usr/bin/env python3
"""
Generate a shell script to provision all lab users at once.

This reduces the number of Ansible round-trips by creating a single
shell script that does all the provisioning work on the remote host.
"""

import csv
import sys
import os
import json
import subprocess
from pathlib import Path

def parse_csv(csv_path):
    """Parse the users CSV file and return list of user records."""
    users = []
    with open(csv_path, 'r') as f:
        reader = csv.reader(f)
        rows = list(reader)

        # Skip header row (first row is the header)
        # Look for rows that start with a timestamp pattern (quoted or unquoted)
        for row in rows[1:]:
            if row and len(row) >= 3:
                timestamp = row[0].strip('"')
                if timestamp.startswith('2026/') or timestamp.startswith('2025/') or timestamp.startswith('2024/'):
                    users.append({
                        'timestamp': timestamp,
                        'has_github': row[1].strip('"') if len(row) > 1 else '',
                        'github_username': row[2].strip('"') if len(row) > 2 else '',
                        'custom_username': row[3].strip('"') if len(row) > 3 else '',
                        'ssh_key': row[4].strip('"') if len(row) > 4 else '',
                    })
    return users

def fetch_all_github_keys(usernames):
    """Fetch SSH keys for all GitHub users in one go."""
    script_dir = Path(__file__).parent
    fetch_script = script_dir / 'fetch-github-keys.py'

    env = os.environ.copy()
    # Load .env file if it exists
    env_file = script_dir.parent / '.env'
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env[key.strip()] = value.strip()

    try:
        result = subprocess.run(
            ['python3', str(fetch_script)] + usernames,
            capture_output=True,
            text=True,
            env=env,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error fetching GitHub keys: {e.stderr}", file=sys.stderr)
        return {}

def generate_shell_script(users, github_keys, kubeconfig_source='/home/dev/.kube/admin.conf'):
    """Generate the provisioning shell script."""
    script = ['#!/bin/bash', 'set -e', '']
    script.append('echo "Starting user provisioning..."')
    script.append('')

    for user in users:
        if user['has_github'] == 'Yes!':
            username = user['github_username']
            keys = github_keys.get(username, [])
        else:
            username = user['custom_username']
            keys = [user['ssh_key']] if user['ssh_key'] else []

        if not username:
            continue

        script.append(f'echo "Provisioning user: {username}"')

        # Create user
        script.append(f'if ! id "{username}" >/dev/null 2>&1; then')
        script.append(f'  useradd -m -s /bin/bash "{username}"')
        script.append(f'  echo "  Created user {username}"')
        script.append('else')
        script.append(f'  echo "  User {username} already exists"')
        script.append('fi')
        script.append('')

        # Set up SSH keys
        if keys:
            script.append(f'# Set up SSH keys for {username}')
            script.append(f'mkdir -p "/home/{username}/.ssh"')
            script.append(f'touch "/home/{username}/.ssh/authorized_keys"')
            script.append(f'chmod 700 "/home/{username}/.ssh"')
            script.append(f'chmod 600 "/home/{username}/.ssh/authorized_keys"')

            for key in keys:
                # Escape the key properly
                escaped_key = key.replace('"', '\\"')
                script.append(f'echo "{escaped_key}" >> "/home/{username}/.ssh/authorized_keys"')

            script.append(f'chown -R "{username}:{username}" "/home/{username}/.ssh"')
            script.append(f'echo "  Added {len(keys)} SSH key(s)"')
            script.append('')

        # Set up .kube directory
        script.append(f'# Set up kubectl config for {username}')
        script.append(f'mkdir -p "/home/{username}/.kube"')
        script.append(f'cp "{kubeconfig_source}" "/home/{username}/.kube/config"')
        script.append(f'chown -R "{username}:{username}" "/home/{username}/.kube"')
        script.append(f'chmod 755 "/home/{username}/.kube"')
        script.append(f'chmod 600 "/home/{username}/.kube/config"')
        script.append('')

        # Set up .bashrc
        script.append(f'# Configure .bashrc for {username}')
        script.append(f'if ! grep -q "KUBECONFIG" "/home/{username}/.bashrc" 2>/dev/null; then')
        script.append(f'  echo "export KUBECONFIG=\\$HOME/.kube/config" >> "/home/{username}/.bashrc"')
        script.append(f'fi')
        script.append('')

    # Clone vllm repo once to /tmp
    script.append('# Clone vllm repo to temporary location')
    script.append('if [ -d "/tmp/vllm-template" ]; then')
    script.append('  rm -rf /tmp/vllm-template')
    script.append('fi')
    script.append('git clone -b demo/kubecon https://github.com/dougbtv/vllm.git /tmp/vllm-template')
    script.append('echo "Cloned vllm repo to /tmp/vllm-template"')
    script.append('')

    # Copy to each user
    for user in users:
        if user['has_github'] == 'Yes!':
            username = user['github_username']
        else:
            username = user['custom_username']

        if not username:
            continue

        script.append(f'# Copy vllm to {username}')
        script.append(f'cp -r /tmp/vllm-template "/home/{username}/vllm"')
        script.append(f'chown -R "{username}:{username}" "/home/{username}/vllm"')

    script.append('')
    script.append('# Clean up')
    script.append('rm -rf /tmp/vllm-template')
    script.append('echo "User provisioning complete!"')

    return '\n'.join(script)

def main():
    if len(sys.argv) < 2:
        print("Usage: generate-provision-script.py <users.csv> [output.sh]", file=sys.stderr)
        sys.exit(1)

    csv_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else '/dev/stdout'

    # Parse CSV
    users = parse_csv(csv_path)
    print(f"Parsed {len(users)} users from CSV", file=sys.stderr)

    # Fetch GitHub keys for all users with GitHub accounts
    github_usernames = [u['github_username'] for u in users
                       if u['has_github'] == 'Yes!' and u['github_username']]

    print(f"Fetching GitHub keys for {len(github_usernames)} users...", file=sys.stderr)
    github_keys = fetch_all_github_keys(github_usernames)
    print(f"Fetched keys for {len(github_keys)} users", file=sys.stderr)

    # Generate shell script
    script = generate_shell_script(users, github_keys)

    # Write output
    if output_path == '/dev/stdout':
        print(script)
    else:
        with open(output_path, 'w') as f:
            f.write(script)
        os.chmod(output_path, 0o755)
        print(f"Generated provisioning script: {output_path}", file=sys.stderr)

if __name__ == '__main__':
    main()
