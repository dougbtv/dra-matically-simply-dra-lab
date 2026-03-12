#!/bin/bash
# GCP configuration for DRA lab 3-VM setup
# Source this file or export these vars before running other scripts

# GCP Project & Network
export GCP_PROJECT="dra-workshop"
export GCP_CONFIG="dra-workshop"
export GCP_REGION="europe-west4"
export GCP_ZONE="europe-west4-a"

# Network
export VPC_NAME="dra-lab-vpc"
export SUBNET_NAME="dra-lab-subnet"
export SUBNET_RANGE="10.240.0.0/24"

# VM Configuration
export VM_PREFIX="dra-lab"
export VM_IMAGE_PROJECT="centos-cloud"
export VM_IMAGE_FAMILY="centos-stream-9"
export VM_MACHINE_TYPE="n2-standard-2"  # 2 vCPUs, 8GB RAM (closest to your 4GB setup)
export VM_BOOT_DISK_SIZE="20GB"

# VM Names
export CONTROL_PLANE_VM="${VM_PREFIX}-control"
export WORKER_1_VM="${VM_PREFIX}-worker1"
export WORKER_2_VM="${VM_PREFIX}-worker2"

# SSH
export SSH_USER="dev"
export SSH_KEY_FILE="${HOME}/.ssh/id_rsa.pub"

# Tags for firewall rules
export CONTROL_PLANE_TAG="dra-control"
export WORKER_TAG="dra-worker"
