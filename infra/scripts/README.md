# Fast User Provisioning Scripts

These scripts optimize the user provisioning process by reducing Ansible round-trips and using the GitHub API with authentication to avoid rate limiting.

## Problem

The original playbook (`05-provision-lab-users.yml`) makes multiple Ansible task calls per user:
- Create user
- Fetch GitHub keys (separate HTTP call per user)
- Set up authorized_keys
- Create .kube directory
- Copy kubeconfig
- Set up .bashrc
- Clone/copy vllm repo

For N users, this means **7N+ Ansible round-trips**, plus N unauthenticated GitHub API calls (subject to rate limiting at ~60 requests/hour).

## Solution

The new approach (`05-provision-lab-users-fast.yml`):

1. **Locally**: Parse CSV and fetch ALL GitHub keys using authenticated API (one batch)
2. **Locally**: Generate a single shell script that provisions all users
3. **Upload once**: Copy the script to the remote host
4. **Run once**: Execute the script (one SSH session)

This reduces it to **~3 Ansible tasks total** (vs 7N+ tasks), and uses authenticated GitHub API calls (5000 requests/hour limit).

## Setup

### 1. Store your GitHub PAT securely

Create `infra/.env`:

```bash
GITHUB_PAT=github_pat_YOUR_TOKEN_HERE
```

This file is gitignored and won't be committed.

### 2. Test the GitHub API

```bash
# Source the environment
source infra/.env

# Test connectivity with auth
curl -H "Authorization: token $GITHUB_PAT" https://api.github.com/rate_limit
```

You should see a much higher rate limit when authenticated.

## Usage

### Option 1: Run the fast playbook

```bash
cd infra/playbooks
ansible-playbook -i ../inventory/gcp-k8s-cluster.yml 05-provision-lab-users-fast.yml
```

### Option 2: Generate and run the script manually

```bash
# Generate the provisioning script
cd infra
source .env
./scripts/generate-provision-script.py users.csv provision-users.sh

# Review the script
less provision-users.sh

# Upload and run it manually
scp provision-users.sh your-host:/tmp/
ssh your-host 'sudo bash /tmp/provision-users.sh'
```

### Option 3: Test GitHub key fetching

```bash
cd infra
source .env
./scripts/fetch-github-keys.py dougbtv maiqueb nonexistantuserduude
```

## Benefits

- **Speed**: 3 Ansible tasks vs 7N+ tasks
- **Rate limits**: Authenticated API = 5000 req/hr vs 60 req/hr
- **Idempotent**: Script checks if users exist before creating
- **Reviewable**: Generate script locally to inspect before running
- **Debuggable**: Single shell script easier to troubleshoot than Ansible loops

## Files

- `fetch-github-keys.py` - Fetch SSH keys from GitHub API for multiple users
- `generate-provision-script.py` - Parse CSV and generate provisioning shell script
- `../playbooks/05-provision-lab-users-fast.yml` - Fast Ansible playbook
- `../.env` - GitHub PAT storage (gitignored)
