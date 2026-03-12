#!/bin/bash
set -euo pipefail

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== Starting GCP DRA lab VMs ==="
echo

# Switch to dra-workshop config
echo "→ Switching to gcloud config: ${GCP_CONFIG}"
gcloud config configurations activate "${GCP_CONFIG}" --quiet
gcloud config set project "${GCP_PROJECT}" --quiet

# Start all VMs
for VM in "${CONTROL_PLANE_VM}" "${WORKER_1_VM}" "${WORKER_2_VM}"; do
    echo "→ Starting ${VM}..."
    if gcloud compute instances describe "${VM}" --zone="${GCP_ZONE}" --quiet 2>/dev/null; then
        STATUS=$(gcloud compute instances describe "${VM}" --zone="${GCP_ZONE}" --format='get(status)')
        if [[ "${STATUS}" == "TERMINATED" ]]; then
            gcloud compute instances start "${VM}" --zone="${GCP_ZONE}" --quiet
            echo "  ✓ Started"
        else
            echo "  Already running (status: ${STATUS})"
        fi
    else
        echo "  VM not found, skipping"
    fi
done

echo
echo "✓ All VMs started!"
echo
echo "Waiting 30s for VMs to boot..."
sleep 30

echo
echo "Current status:"
gcloud compute instances list \
    --filter="name~^${VM_PREFIX}-" \
    --format="table(name,zone,machineType,networkInterfaces[0].networkIP:label=INTERNAL_IP,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP,status)"

echo
echo "VMs are booting. Wait ~1 minute for SSH to be available."
echo
echo "Regenerate inventory if external IPs changed:"
echo "  ./generate-inventory.sh"
