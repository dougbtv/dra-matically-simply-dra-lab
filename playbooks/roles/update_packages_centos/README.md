# update_packages_centos Role

This role updates all packages on CentOS/RHEL systems using DNF, detects kernel updates, and automatically reboots if the kernel was updated to ensure the new kernel is loaded.

Use `nvidiapackage_update_centos_force_reboot` set to `true` to force a reboot during the process.

## Overview

The `update_packages_centos` role performs the following operations:

1. **System Validation** - Ensures the role runs only on CentOS/RHEL systems
2. **Kernel Tracking** - Records current kernel version before updates
3. **Package Updates** - Updates all packages using DNF
4. **Kernel Detection** - Detects if kernel packages were updated
5. **Conditional Reboot** - Reboots only if kernel was updated
6. **Verification** - Confirms new kernel is loaded after reboot

## Features

### Smart Kernel Detection
- Records kernel version before updates
- Detects kernel package updates in DNF results
- Only reboots when necessary (kernel updates)

### Safe Update Process
- Validates system compatibility before proceeding
- Checks for available updates before attempting
- Graceful handling of up-to-date systems

### Comprehensive Reporting
- Shows update status and package counts
- Displays kernel version comparisons
- Provides clear summary of actions taken

## Variables

```yaml
# Reboot configuration
reboot_timeout: 600        # Maximum time to wait for reboot
reboot_delay: 10          # Delay before reboot
nvidiapackage_update_centos_force_reboot: false # for a reboot

# Update behavior
update_all_packages: true  # Whether to update all packages
update_cache: true        # Whether to update package cache
```

## Usage

### Basic Usage
```yaml
- name: Update system packages
  hosts: centos_servers
  become: true
  roles:
    - update_packages_centos
```

### With Custom Configuration
```yaml
- name: Update system packages with custom settings
  hosts: centos_servers
  become: true
  vars:
    reboot_timeout: 300
    update_all_packages: true
  roles:
    - update_packages_centos
```

### In Multi-Role Playbook
```yaml
- name: Complete system setup
  hosts: servers
  become: true
  roles:
    - update_packages_centos  # Update packages first
    - nvidia_driver_centos    # Install drivers on updated system
    - other_roles            # Additional configuration
```

## Process Flow

### Step 1: System Validation
- Checks OS family (must be RedHat)
- Displays current system and kernel information

### Step 2: Update Check
- Records current kernel version
- Checks for available package updates
- Reports update availability status

### Step 3: Package Updates
- Updates all packages if updates are available
- Tracks which packages were updated
- Reports update results

### Step 4: Kernel Detection
- Analyzes updated packages for kernel updates
- Sets kernel_updated flag based on results
- Reports kernel update status

### Step 5: Conditional Reboot
- Reboots only if kernel was updated
- Waits for system to come back online
- Skips reboot if no kernel update occurred

### Step 6: Verification
- Re-gathers system facts after reboot
- Compares old and new kernel versions
- Provides comprehensive summary

## Example Output

### No Updates Available
```
TASK [Display update status] 
ok: [server] => {
    "msg": "System is up to date"
}

TASK [Package update summary]
ok: [server] => {
    "msg": "Package Update Complete!\n\nStatus:\n- Packages updated: No updates available\n- Kernel updated: No\n- System rebooted: No\n- Current kernel: 5.14.0-284.30.1.el9_2.x86_64\n\nSystem is ready for subsequent role execution."
}
```

### With Kernel Update
```
TASK [Display update status]
ok: [server] => {
    "msg": "Updates available"
}

TASK [Display package update results]
ok: [server] => {
    "msg": "Package update completed. 15 packages updated."
}

TASK [Display kernel update status]
ok: [server] => {
    "msg": "Kernel was updated - reboot required"
}

TASK [Display kernel version comparison]
ok: [server] => {
    "msg": "Kernel update summary:\n- Previous kernel: 5.14.0-284.25.1.el9_2.x86_64\n- Current kernel: 5.14.0-284.30.1.el9_2.x86_64\n- Kernel changed: true"
}
```

## Compatibility

### Supported Systems
- CentOS 9
- RHEL 9
- Rocky Linux 9
- AlmaLinux 9

### Requirements
- DNF package manager
- Root privileges
- Network connectivity for package downloads

## Benefits

### For NVIDIA Driver Installation
- Ensures latest kernel is running before driver installation
- Prevents DKMS compilation issues with mismatched kernels
- Reduces driver installation failures

### For System Stability
- Applies security updates before configuration
- Ensures consistent system state
- Minimizes unexpected reboots during multi-role execution

## Troubleshooting

### Common Issues

**Role Fails on Non-CentOS Systems**
```
TASK [Check if running on CentOS/RHEL]
fatal: [server]: FAILED! => {"msg": "This role is designed for CentOS/RHEL systems only"}
```
Solution: Only run on CentOS/RHEL systems or use OS-specific conditionals.

**Package Update Failures**
```bash
# Check repository access
dnf repolist

# Check for conflicting processes
dnf check

# Review available updates
dnf check-update
```

**Reboot Issues**
```bash
# Check system status
systemctl status

# Review boot logs
journalctl -b
```

## Integration Notes

### Best Practices
1. **Run Early**: Execute before roles that depend on specific kernel versions
2. **NVIDIA Drivers**: Essential before GPU driver installation
3. **Development Tools**: Update before installing development packages
4. **Container Runtimes**: Update before Docker/Podman installation

### Role Ordering
```yaml
roles:
  - update_packages_centos    # First - update system
  - nvidia_driver_centos      # Second - install drivers
  - container_runtime         # Third - install containers
  - application_roles         # Last - application setup
```

This role provides a robust foundation for system configuration by ensuring all packages are current and the latest kernel is running before subsequent role execution.
