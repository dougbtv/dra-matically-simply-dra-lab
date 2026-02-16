# k8shazgpu Ansible Role

This role installs and deploys k8shazgpu, a Kubernetes utility for GPU allocation using Dynamic Resource Allocation (DRA).

## Description

The k8shazgpu role performs the following tasks:
1. Installs Golang 1.23+ (if not already present)
2. Clones the canhazgpu repository from GitHub
3. Builds the k8shazgpu CLI binary
4. Installs the binary to `/usr/local/bin/k8shazgpu`
5. Deploys k8shazgpu components to the Kubernetes cluster
6. Validates the deployment

## Requirements

- Ansible 2.9+
- Kubernetes cluster with CRI-O or containerd
- kubectl configured on the control plane node
- Git installed on target hosts

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```yaml
# Golang installation
golang_version: "1.23.0"
golang_download_url: "https://go.dev/dl/go{{ golang_version }}.linux-amd64.tar.gz"
golang_install_dir: "/usr/local"

# k8shazgpu repository
k8shazgpu_repo_url: "https://github.com/dougbtv/canhazgpu.git"
k8shazgpu_repo_branch: "k8shazgpu-demo-worthy"
k8shazgpu_clone_dir: "/tmp/canhazgpu"

# k8shazgpu binary
k8shazgpu_binary_install_path: "/usr/local/bin/k8shazgpu"

# Deployment
k8shazgpu_deploy: true      # Deploy to Kubernetes cluster
k8shazgpu_validate: true    # Run validation checks
```

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Install k8shazgpu
  hosts: k8s_control_plane
  become: false
  
  vars:
    kubeconfig: "/home/{{ ansible_user }}/.kube/admin.conf"
  
  environment:
    KUBECONFIG: "{{ kubeconfig }}"
  
  roles:
    - k8shazgpu
```

## Example Usage with deploy-demo-assets.yml

The role is integrated into the `deploy-demo-assets.yml` playbook:

```bash
ansible-playbook -i inventory/centos9-k8s-cluster.yml playbooks/deploy-demo-assets.yml
```

## Verification

After deployment, verify the installation:

```bash
# Check k8shazgpu binary
k8shazgpu --help

# Check deployed pods
kubectl get pods -A | grep canhazgpu-system

# Expected output shows:
# - canhazgpu-controller-* (1 pod)
# - canhazgpu-kubeletplugin-* (1 pod per node)
# - canhazgpu-nodeagent-* (1 pod per node)

# Check daemonsets
kubectl get daemonset -n canhazgpu-system

# Check deployment
kubectl get deployment -n canhazgpu-system
```

## Components Deployed

The role deploys the following k8shazgpu components:

1. **canhazgpu-controller**: DRA controller managing GPU allocation
2. **canhazgpu-kubeletplugin**: Kubelet plugin for DRA (daemonset)
3. **canhazgpu-nodeagent**: Node agent for GPU management (daemonset)

## Source

Repository: https://github.com/dougbtv/canhazgpu/tree/k8shazgpu-demo-worthy

## License

MIT

## Author Information

Created for the Stratus infrastructure automation project.
