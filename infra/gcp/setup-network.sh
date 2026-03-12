#!/bin/bash
set -euo pipefail

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== Setting up GCP network for DRA lab ==="
echo "Project: ${GCP_PROJECT}"
echo "Region: ${GCP_REGION}"
echo "Zone: ${GCP_ZONE}"
echo

# Switch to dra-workshop config
echo "→ Switching to gcloud config: ${GCP_CONFIG}"
gcloud config configurations activate "${GCP_CONFIG}"
gcloud config set project "${GCP_PROJECT}"

# Create VPC network
echo "→ Creating VPC network: ${VPC_NAME}"
if gcloud compute networks describe "${VPC_NAME}" --quiet 2>/dev/null; then
    echo "  VPC already exists, skipping"
else
    gcloud compute networks create "${VPC_NAME}" \
        --subnet-mode=custom \
        --bgp-routing-mode=regional
fi

# Create subnet
echo "→ Creating subnet: ${SUBNET_NAME}"
if gcloud compute networks subnets describe "${SUBNET_NAME}" --region="${GCP_REGION}" --quiet 2>/dev/null; then
    echo "  Subnet already exists, skipping"
else
    gcloud compute networks subnets create "${SUBNET_NAME}" \
        --network="${VPC_NAME}" \
        --region="${GCP_REGION}" \
        --range="${SUBNET_RANGE}"
fi

# Firewall: Allow internal traffic between all VMs
echo "→ Creating firewall rule: allow-internal"
if gcloud compute firewall-rules describe "${VPC_NAME}-allow-internal" --quiet 2>/dev/null; then
    echo "  Firewall rule already exists, skipping"
else
    gcloud compute firewall-rules create "${VPC_NAME}-allow-internal" \
        --network="${VPC_NAME}" \
        --allow=tcp,udp,icmp \
        --source-ranges="${SUBNET_RANGE}"
fi

# Firewall: Allow SSH to control plane from anywhere
echo "→ Creating firewall rule: allow-ssh-control-plane"
if gcloud compute firewall-rules describe "${VPC_NAME}-allow-ssh-control" --quiet 2>/dev/null; then
    echo "  Firewall rule already exists, skipping"
else
    gcloud compute firewall-rules create "${VPC_NAME}-allow-ssh-control" \
        --network="${VPC_NAME}" \
        --allow=tcp:22 \
        --source-ranges=0.0.0.0/0 \
        --target-tags="${CONTROL_PLANE_TAG}"
fi

echo
echo "✓ Network setup complete!"
echo
echo "VPC: ${VPC_NAME}"
echo "Subnet: ${SUBNET_NAME} (${SUBNET_RANGE})"
echo "Firewall rules:"
echo "  - ${VPC_NAME}-allow-internal (internal traffic)"
echo "  - ${VPC_NAME}-allow-ssh-control (SSH to control plane)"
