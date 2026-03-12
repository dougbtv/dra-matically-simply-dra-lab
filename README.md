# DRA-matically Simply DRA Lab

Workshop materials and infrastructure for hands-on Dynamic Resource Allocation (DRA) in Kubernetes.

## 🎯 Overview

This repository contains everything you need to set up and run a hands-on Kubernetes DRA workshop. Participants will learn how to use Kubernetes 1.35+ Dynamic Resource Allocation to manage GPU resources across a multi-node cluster.

## 🚢 Kubecon EU '26 - Amsterdam!

* Slides link! [TBD!]
* Recording link! [TBD!]

## 📚 Workshop Materials

### Lab sign-up!

Signup for the lab [USING GOOGLE FORMS](https://docs.google.com/forms/d/e/1FAIpQLSc8GbcDQisTcwhFLuZaZc_lk_PRDi1M8RGR4WuWSrPACMe4dw/formResponse)

If you need it, you'll also have to setup [a GitHub public ssh key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account), or [generate an SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).


Instructor note: Need to get to the form download?

### [Tutorial Steps](./TUTORIAL_STEPS.md)
Follow the step-by-step tutorial to learn DRA concepts hands-on.

### DRA Driver Developement

Part of this talk includes an example DRA Driver!

* https://github.com/dougbtv/canhazgpu/tree/k8shazgpu-demo-worthy

It's on my fork of [canhazgpu](https://github.com/russellb/canhazgpu)

### [Infrastructure Setup](./infra/)

Complete infrastructure automation for deploying the lab environment:

- **[Vagrant/Libvirt](./infra/)** - Local VM deployment option
- **[GCP Deployment](./infra/gcp/)** - Deploy to Google Cloud Platform
- **[Ansible Playbooks](./infra/playbooks/)** - Kubernetes cluster setup with DRA support

This heavily borrows from my dear friend [Tomofumi Hayashi](https://github.com/s1061123)'s project: [Kube2](https://github.com/s1061123/kube2) (a set of ansible playbooks for spinning up Kubernetes)!

## 🚀 Quick Start

### For Workshop Participants

1. Review the [Tutorial Steps](./TUTORIAL_STEPS.md)
2. Your instructor will provide cluster access details
3. Follow along with the hands-on exercises

### For Workshop Instructors

1. Deploy the infrastructure:
   ```bash
   cd infra/gcp
   ./deploy-all.sh
   ```

2. Run the setup playbooks:
   ```bash
   cd infra
   ansible-playbook playbooks/02-setup-k8s-cluster.yml -i inventory/gcp-k8s-cluster.yml
   ansible-playbook playbooks/03-deploy-demo-assets.yml -i inventory/gcp-k8s-cluster.yml
   ansible-playbook playbooks/04-install-k8shazgpu.yml -i inventory/gcp-k8s-cluster.yml
   ```

3. Provision user accounts (optional):
   ```bash
   ansible-playbook playbooks/05-provision-lab-users.yml -i inventory/gcp-k8s-cluster.yml
   ```

## 🔗 Additional Resources

<!-- Add your x, y, z pointers here -->

## 🛠 Technology Stack

- **Kubernetes 1.35+** with Dynamic Resource Allocation (DRA) enabled
- **k8shazgpu** - DRA controller for GPU resource management
- **[fake-gpu-operator](https://github.com/run-ai/fake-gpu-operator)** - Simulated GPU environment for testing
- **[canhazgpu](https://github.com/russellb/canhazgpu)** - CLI tool for GPU reservations

## 📝 License

<!-- Add your license info -->

## 👥 Contributing

<!-- Add contribution guidelines if needed -->
