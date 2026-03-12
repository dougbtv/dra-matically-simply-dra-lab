# GCP Infrastructure for DRA Lab

This directory contains gcloud CLI scripts to deploy the DRA lab's 3-VM Kubernetes cluster on Google Cloud Platform.

## Architecture

- **VPC Network**: `dra-lab-vpc` with custom subnet `10.240.0.0/24`
- **3 VMs**:
  - **Control plane**: CentOS Stream 9, 2 vCPUs, 8GB RAM, 50GB disk, external IP (SSH from WAN)
  - **Worker 1**: CentOS Stream 9, 2 vCPUs, 8GB RAM, 50GB disk, external IP
  - **Worker 2**: CentOS Stream 9, 2 vCPUs, 8GB RAM, 50GB disk, external IP
- **Firewall**:
  - Internal traffic (TCP/UDP/ICMP) between all VMs
  - SSH (port 22) from anywhere to all VMs

## Prerequisites

1. **gcloud CLI** installed and authenticated
2. **GCP project** with Compute Engine API enabled
3. **gcloud configuration** named `dra-workshop` (or customize in `config.sh`)
4. **SSH key** at `~/.ssh/id_rsa.pub` (or customize in `config.sh`)

## Setup gcloud config

```bash
# Create a new config for the workshop project
gcloud config configurations create dra-workshop
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Switch back to default for Claude to work
gcloud config configurations activate default
```

## Configuration

Edit `config.sh` before running:

```bash
# REQUIRED: Update your project ID
export GCP_PROJECT="your-project-id"

# Optional: Customize region/zone, VM specs, etc.
export GCP_REGION="us-central1"
export GCP_ZONE="us-central1-a"
export VM_MACHINE_TYPE="n2-standard-2"  # 2 vCPUs, 8GB RAM
```

## Usage

### 1. Setup network infrastructure

```bash
./setup-network.sh
```

Creates VPC, subnet, and firewall rules.

### 2. Create VMs

```bash
./create-vms.sh
```

Creates 3 VMs:
- `dra-lab-control` (control plane, external IP)
- `dra-lab-worker1` (worker, internal only)
- `dra-lab-worker2` (worker, internal only)

### 3. Generate Ansible inventory

```bash
./generate-inventory.sh
```

Creates `../inventory/gcp-k8s-cluster.yml` with:
- Control plane accessible via external IP
- Workers accessible via SSH ProxyJump through control plane

### 4. Run Ansible playbooks

```bash
cd ..
ansible-playbook playbooks/02-setup-k8s-cluster.yml -i inventory/gcp-k8s-cluster.yml
ansible-playbook playbooks/03-deploy-demo-assets.yml -i inventory/gcp-k8s-cluster.yml
ansible-playbook playbooks/04-install-k8shazgpu.yml -i inventory/gcp-k8s-cluster.yml
```

### 5. Teardown (cleanup)

```bash
./teardown.sh
```

Deletes all GCP resources (VMs, firewall rules, network).

## SSH Access

All VMs have external IPs and can be accessed directly:

```bash
ssh dev@<control-plane-external-ip>
ssh dev@<worker1-external-ip>
ssh dev@<worker2-external-ip>
```

Or let Ansible handle it with the generated inventory.

## Costs

Approximate costs (europe-west4, on-demand):
- **n2-standard-2**: ~$0.10/hour × 3 VMs = ~$0.30/hour (~$216/month)
- **50GB pd-standard disk**: ~$0.04/GB/month × 50GB × 3 = ~$6/month
- **External IP**: ~$0.005/hour × 3 = ~$0.015/hour (~$11/month)

**Total**: ~$233/month for 24/7, or **~$153 for 3 weeks**. Stop VMs when not in use!

## Switching Between Configs

```bash
# For gcloud operations on GCP VMs
gcloud config configurations activate dra-workshop

# Switch back to default (required for Claude)
gcloud config configurations activate default
```

The scripts automatically switch to `dra-workshop` when running.

## Troubleshooting

**"Permission denied" during VM creation**:
- Ensure Compute Engine API is enabled
- Check IAM permissions (need `compute.instanceAdmin` or similar)

**Can't SSH to VMs**:
- Ensure your firewall allows SSH (port 22) from your IP
- Check that the `dev` user was created via startup script
- Verify your SSH key is in `/home/dev/.ssh/authorized_keys`

**VMs won't start**:
- Check quotas: `gcloud compute project-info describe --project=YOUR_PROJECT`
- Try a different zone if capacity issues

**Startup script not running**:
- Check serial console: `gcloud compute instances get-serial-port-output dra-lab-control --zone=us-central1-a`
- May take 30-60s for script to complete

## Files

- `config.sh` - Central configuration (project, region, VM specs)
- `setup-network.sh` - Create VPC and firewall rules
- `create-vms.sh` - Launch 3 VMs
- `generate-inventory.sh` - Generate Ansible inventory
- `teardown.sh` - Delete all resources
- `README.md` - This file
