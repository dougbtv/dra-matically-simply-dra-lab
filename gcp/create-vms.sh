#!/bin/bash
set -euo pipefail

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== Creating GCP VMs for DRA lab ==="
echo "Machine type: ${VM_MACHINE_TYPE}"
echo "Image: ${VM_IMAGE_FAMILY}"
echo

# Switch to dra-workshop config
echo "→ Switching to gcloud config: ${GCP_CONFIG}"
gcloud config configurations activate "${GCP_CONFIG}"
gcloud config set project "${GCP_PROJECT}"

# Read SSH public key
if [[ ! -f "${SSH_KEY_FILE}" ]]; then
    echo "ERROR: SSH key not found at ${SSH_KEY_FILE}"
    exit 1
fi
SSH_PUB_KEY=$(cat "${SSH_KEY_FILE}")

# Startup script to create dev user and configure SSH
STARTUP_SCRIPT='#!/bin/bash
set -e
useradd -m -s /bin/bash dev || true
mkdir -p /home/dev/.ssh
echo "SSH_PUBLIC_KEY_PLACEHOLDER" > /home/dev/.ssh/authorized_keys
chmod 600 /home/dev/.ssh/authorized_keys
chown -R dev:dev /home/dev/.ssh
echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
'

# Replace placeholder with actual SSH key
STARTUP_SCRIPT="${STARTUP_SCRIPT//SSH_PUBLIC_KEY_PLACEHOLDER/${SSH_PUB_KEY}}"

# Create control plane VM (with external IP)
echo "→ Creating control plane VM: ${CONTROL_PLANE_VM}"
if gcloud compute instances describe "${CONTROL_PLANE_VM}" --zone="${GCP_ZONE}" --quiet 2>/dev/null; then
    echo "  VM already exists, skipping"
else
    gcloud compute instances create "${CONTROL_PLANE_VM}" \
        --zone="${GCP_ZONE}" \
        --machine-type="${VM_MACHINE_TYPE}" \
        --subnet="${SUBNET_NAME}" \
        --network-tier=PREMIUM \
        --maintenance-policy=MIGRATE \
        --image-project="${VM_IMAGE_PROJECT}" \
        --image-family="${VM_IMAGE_FAMILY}" \
        --boot-disk-size="${VM_BOOT_DISK_SIZE}" \
        --boot-disk-type=pd-standard \
        --boot-disk-device-name="${CONTROL_PLANE_VM}" \
        --tags="${CONTROL_PLANE_TAG}" \
        --metadata=startup-script="${STARTUP_SCRIPT}"
fi

# Create worker VMs (no external IP - internal only)
for WORKER_VM in "${WORKER_1_VM}" "${WORKER_2_VM}"; do
    echo "→ Creating worker VM: ${WORKER_VM}"
    if gcloud compute instances describe "${WORKER_VM}" --zone="${GCP_ZONE}" --quiet 2>/dev/null; then
        echo "  VM already exists, skipping"
    else
        gcloud compute instances create "${WORKER_VM}" \
            --zone="${GCP_ZONE}" \
            --machine-type="${VM_MACHINE_TYPE}" \
            --subnet="${SUBNET_NAME}" \
            --no-address \
            --maintenance-policy=MIGRATE \
            --image-project="${VM_IMAGE_PROJECT}" \
            --image-family="${VM_IMAGE_FAMILY}" \
            --boot-disk-size="${VM_BOOT_DISK_SIZE}" \
            --boot-disk-type=pd-standard \
            --boot-disk-device-name="${WORKER_VM}" \
            --tags="${WORKER_TAG}" \
            --metadata=startup-script="${STARTUP_SCRIPT}"
    fi
done

echo
echo "✓ VMs created successfully!"
echo
echo "Fetching VM details..."
echo

# Display VM information
gcloud compute instances list \
    --filter="name~^${VM_PREFIX}-" \
    --format="table(name,zone,machineType,networkInterfaces[0].networkIP:label=INTERNAL_IP,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP,status)"

echo
echo "Next steps:"
echo "  1. Wait ~30s for VMs to boot and run startup script"
echo "  2. SSH to control plane: ssh ${SSH_USER}@\$(gcloud compute instances describe ${CONTROL_PLANE_VM} --zone=${GCP_ZONE} --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"
echo "  3. Generate inventory: ./generate-inventory.sh"
