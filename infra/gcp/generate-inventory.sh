#!/bin/bash
set -euo pipefail

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== Generating Ansible inventory for GCP VMs ==="

# Switch to dra-workshop config
gcloud config configurations activate "${GCP_CONFIG}" --quiet
gcloud config set project "${GCP_PROJECT}" --quiet

# Get control plane IPs
CONTROL_EXTERNAL_IP=$(gcloud compute instances describe "${CONTROL_PLANE_VM}" \
    --zone="${GCP_ZONE}" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
CONTROL_INTERNAL_IP=$(gcloud compute instances describe "${CONTROL_PLANE_VM}" \
    --zone="${GCP_ZONE}" \
    --format='get(networkInterfaces[0].networkIP)')

# Get worker IPs (both internal and external)
WORKER1_INTERNAL_IP=$(gcloud compute instances describe "${WORKER_1_VM}" \
    --zone="${GCP_ZONE}" \
    --format='get(networkInterfaces[0].networkIP)')
WORKER1_EXTERNAL_IP=$(gcloud compute instances describe "${WORKER_1_VM}" \
    --zone="${GCP_ZONE}" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

WORKER2_INTERNAL_IP=$(gcloud compute instances describe "${WORKER_2_VM}" \
    --zone="${GCP_ZONE}" \
    --format='get(networkInterfaces[0].networkIP)')
WORKER2_EXTERNAL_IP=$(gcloud compute instances describe "${WORKER_2_VM}" \
    --zone="${GCP_ZONE}" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

# Generate inventory file
INVENTORY_FILE="${SCRIPT_DIR}/../inventory/gcp-k8s-cluster.yml"
mkdir -p "$(dirname "${INVENTORY_FILE}")"

cat > "${INVENTORY_FILE}" << EOF
---
# Auto-generated inventory for GCP DRA lab VMs
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

all:
  vars:
    ansible_user: ${SSH_USER}
    ansible_ssh_private_key_file: ${SSH_KEY_FILE%.pub}
    ansible_python_interpreter: /usr/bin/python3

  children:
    k8s_control_plane:
      hosts:
        ${CONTROL_PLANE_VM}:
          ansible_host: ${CONTROL_EXTERNAL_IP}
          private_ip: ${CONTROL_INTERNAL_IP}

    k8s_workers:
      hosts:
        ${WORKER_1_VM}:
          ansible_host: ${WORKER1_EXTERNAL_IP}
          private_ip: ${WORKER1_INTERNAL_IP}

        ${WORKER_2_VM}:
          ansible_host: ${WORKER2_EXTERNAL_IP}
          private_ip: ${WORKER2_INTERNAL_IP}

    k8s_cluster:
      children:
        k8s_control_plane:
        k8s_workers:
EOF

echo "✓ Inventory generated: ${INVENTORY_FILE}"
echo
echo "Control plane: ${CONTROL_PLANE_VM}"
echo "  External IP: ${CONTROL_EXTERNAL_IP}"
echo "  Internal IP: ${CONTROL_INTERNAL_IP}"
echo "Worker 1: ${WORKER_1_VM}"
echo "  External IP: ${WORKER1_EXTERNAL_IP}"
echo "  Internal IP: ${WORKER1_INTERNAL_IP}"
echo "Worker 2: ${WORKER_2_VM}"
echo "  External IP: ${WORKER2_EXTERNAL_IP}"
echo "  Internal IP: ${WORKER2_INTERNAL_IP}"
echo
echo "Test connectivity:"
echo "  ansible all -i ${INVENTORY_FILE} -m ping"
