#!/bin/bash
set -euo pipefail

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== Tearing down GCP DRA lab infrastructure ==="
echo "WARNING: This will delete all VMs, firewall rules, and network resources."
echo

read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Switch to dra-workshop config
echo "→ Switching to gcloud config: ${GCP_CONFIG}"
gcloud config configurations activate "${GCP_CONFIG}"
gcloud config set project "${GCP_PROJECT}"

# Delete VMs
echo "→ Deleting VMs..."
for VM in "${CONTROL_PLANE_VM}" "${WORKER_1_VM}" "${WORKER_2_VM}"; do
    if gcloud compute instances describe "${VM}" --zone="${GCP_ZONE}" --quiet 2>/dev/null; then
        echo "  Deleting ${VM}..."
        gcloud compute instances delete "${VM}" --zone="${GCP_ZONE}" --quiet
    else
        echo "  ${VM} not found, skipping"
    fi
done

# Delete firewall rules
echo "→ Deleting firewall rules..."
for RULE in "${VPC_NAME}-allow-internal" "${VPC_NAME}-allow-ssh-control"; do
    if gcloud compute firewall-rules describe "${RULE}" --quiet 2>/dev/null; then
        echo "  Deleting ${RULE}..."
        gcloud compute firewall-rules delete "${RULE}" --quiet
    else
        echo "  ${RULE} not found, skipping"
    fi
done

# Delete subnet
echo "→ Deleting subnet..."
if gcloud compute networks subnets describe "${SUBNET_NAME}" --region="${GCP_REGION}" --quiet 2>/dev/null; then
    gcloud compute networks subnets delete "${SUBNET_NAME}" --region="${GCP_REGION}" --quiet
else
    echo "  Subnet not found, skipping"
fi

# Delete VPC network
echo "→ Deleting VPC network..."
if gcloud compute networks describe "${VPC_NAME}" --quiet 2>/dev/null; then
    gcloud compute networks delete "${VPC_NAME}" --quiet
else
    echo "  VPC not found, skipping"
fi

# Remove generated inventory
INVENTORY_FILE="${SCRIPT_DIR}/../inventory/gcp-k8s-cluster.yml"
if [[ -f "${INVENTORY_FILE}" ]]; then
    echo "→ Removing generated inventory: ${INVENTORY_FILE}"
    rm -f "${INVENTORY_FILE}"
fi

echo
echo "✓ Teardown complete!"
echo
echo "Don't forget to switch back to default gcloud config:"
echo "  gcloud config configurations activate default"
