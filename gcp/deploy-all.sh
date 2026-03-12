#!/bin/bash
set -euo pipefail

# All-in-one deployment script for GCP DRA lab
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== GCP DRA Lab - Full Deployment ==="
echo
echo "This will:"
echo "  1. Setup VPC network and firewall rules"
echo "  2. Create 3 VMs (1 control + 2 workers)"
echo "  3. Generate Ansible inventory"
echo
read -p "Continue? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo
echo "Step 1/3: Setting up network..."
"${SCRIPT_DIR}/setup-network.sh"

echo
echo "Step 2/3: Creating VMs..."
"${SCRIPT_DIR}/create-vms.sh"

echo
echo "Waiting 30s for VMs to boot and run startup scripts..."
sleep 30

echo
echo "Step 3/3: Generating inventory..."
"${SCRIPT_DIR}/generate-inventory.sh"

echo
echo "✓ Deployment complete!"
echo
echo "Next steps:"
echo "  1. Test connectivity:"
echo "       ansible all -i ../inventory/gcp-k8s-cluster.yml -m ping"
echo
echo "  2. Setup Kubernetes cluster:"
echo "       ansible-playbook playbooks/02-setup-k8s-cluster.yml -i inventory/gcp-k8s-cluster.yml"
echo
echo "  3. Deploy demo assets:"
echo "       ansible-playbook playbooks/03-deploy-demo-assets.yml -i inventory/gcp-k8s-cluster.yml"
echo
echo "  4. Install k8shazgpu:"
echo "       ansible-playbook playbooks/04-install-k8shazgpu.yml -i inventory/gcp-k8s-cluster.yml"
echo
echo "Don't forget to switch back to default gcloud config when done:"
echo "  gcloud config configurations activate default"
