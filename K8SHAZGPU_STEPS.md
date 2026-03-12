# k8shazgpu Workshop - Kubernetes Deep Dive

Exploring GPU scheduling with Dynamic Resource Allocation (DRA) from a Kubernetes perspective.

## Prerequisites

You're logged into your workshop environment with:
- `kubectl` configured for the cluster
- `k8shazgpu` CLI available
- Access to a cloned vLLM repository at `~/vllm`

## Step 1: Explore the DRA Infrastructure

First, see what DRA components are running in the cluster:

```bash
# Check the canhazgpu-system namespace
kubectl get all -n canhazgpu-system

# Inspect the DRA controller (allocates GPUs)
kubectl describe deployment canhazgpu-controller -n canhazgpu-system

# Check the kubelet plugins (one per node)
kubectl get daemonset canhazgpu-kubeletplugin -n canhazgpu-system

# Check the node agents (cache + GPU state management)
kubectl get daemonset canhazgpu-nodeagent -n canhazgpu-system
```

Look for:
- How many replicas of each component
- Which nodes they're running on
- Container images being used

## Step 2: Inspect ResourceSlices (DRA Device Advertisement)

DRA uses ResourceSlices to advertise available devices:

```bash
# List all ResourceSlices
kubectl get resourceslices

# Inspect a specific ResourceSlice
kubectl get resourceslices -o yaml | head -80

# See which GPUs are advertised per node
kubectl get resourceslices -o json | jq '.items[] | {node: .spec.nodeName, devices: .spec.devices}'
```

Look for:
- `spec.devices` - Lists individual GPU devices (gpu0, gpu1, etc.)
- `spec.pool` - Device pool name
- `spec.driver` - Driver name (canhazgpu.com)
- Node assignment

## Step 3: Watch ResourceClaim Creation

In one terminal, watch for ResourceClaims:

```bash
kubectl get resourceclaims -A -w
```

In another terminal, create a workload:

```bash
cd ~/vllm
k8shazgpu vllm run --name demo --gpus 1 -- sleep 300
```

Watch the ResourceClaim appear and see its lifecycle!

## Step 4: Deep Dive into a ResourceClaim

```bash
# Get the ResourceClaim details
kubectl get resourceclaim demo -o yaml

# Check key fields
kubectl get resourceclaim demo -o jsonpath='{.status.allocation}' | jq .
```

Key things to inspect:

**Before allocation:**
- `spec.devices.requests` - What was requested (GPU count)
- `status.allocation` - Should be null/empty

**After allocation:**
```bash
# Node selector showing where GPUs were allocated
kubectl get resourceclaim demo -o jsonpath='{.status.allocation.nodeSelector}' | jq .

# Device results showing which specific GPUs
kubectl get resourceclaim demo -o jsonpath='{.status.allocation.devices.results}' | jq .
```

Look for:
- `device` field - Shows GPU IDs like "gpu0", "gpu1"
- `driver` field - Should be "canhazgpu.com"
- Node selector matches - Ensures pod lands on right node

## Step 5: Examine the Pod Spec

See how the Pod references the ResourceClaim:

```bash
# Get the Pod that was created
kubectl get pod demo-vllm-pod -o yaml

# Check the ResourceClaim reference
kubectl get pod demo-vllm-pod -o jsonpath='{.spec.resourceClaims}' | jq .

# Inspect volume mounts (cache integration)
kubectl get pod demo-vllm-pod -o jsonpath='{.spec.volumes}' | jq .
```

Key things to find:

1. **ResourceClaim binding:**
   - `spec.resourceClaims[].name` - References the ResourceClaim
   - `spec.resourceClaims[].resourceClaimName` - Links to the claim

2. **Volume mounts:**
   - `/workdir` - Git repository mount
   - `/models` - Model cache mount
   - Check the `hostPath` sources

3. **Container spec:**
   - No `CUDA_VISIBLE_DEVICES` in env vars (CDI handles it!)
   - Check `resources.claims` reference

## Step 6: Watch Controller Allocation Logs

See the controller decide where to allocate GPUs:

```bash
# Tail controller logs
kubectl logs -f -n canhazgpu-system -l app=canhazgpu-controller

# In another terminal, create a new workload
k8shazgpu vllm run --name demo2 --gpus 2 -- sleep 300
```

Look for log lines showing:
- ResourceClaim reconciliation
- Node selection logic
- HTTP requests to node agents
- Allocation success/failure

## Step 7: Inspect Node Agent GPU Allocation

Node agents manage GPU state via Redis. Check their logs:

```bash
# Pick a node agent pod
kubectl get pods -n canhazgpu-system -l app=canhazgpu-nodeagent

# Tail its logs
kubectl logs -f -n canhazgpu-system canhazgpu-nodeagent-XXXXX
```

Look for:
- HTTP requests from controller (`handleAllocation`)
- Redis operations (GPU reservation)
- Cache reconciliation events

## Step 8: Explore Custom Resource Definitions

Check the CRDs created for cache management:

```bash
# List cache-related CRDs
kubectl get crds | grep cache

# Inspect CachePlan CRD
kubectl get crd cacheplans.canhazgpu.com -o yaml

# See NodeCacheStatus CRD
kubectl get crd nodecachestatuses.canhazgpu.com -o yaml

# Get actual cache plans
kubectl get cacheplans -A

# Get cache status per node
kubectl get nodecachestatuses -A
```

Inspect a NodeCacheStatus:

```bash
kubectl get nodecachestatus -n canhazgpu-system -o yaml | head -50
```

Look for:
- `spec.images` - Cached container images
- `spec.gitRepositories` - Cloned git repos
- `spec.models` - Downloaded models
- Status fields showing progress

## Step 9: Multiple ResourceClaims and Scheduling

Create multiple workloads to see GPU distribution:

```bash
# Watch ResourceClaims and Pods
watch -n 1 'kubectl get resourceclaims,pods -o wide | grep -E "NAME|demo"'

# In another terminal, launch 3 workloads
k8shazgpu vllm run --name demo-a --gpus 1 -- sleep 300
k8shazgpu vllm run --name demo-b --gpus 1 -- sleep 300
k8shazgpu vllm run --name demo-c --gpus 1 -- sleep 300
```

Check distribution:

```bash
# See which nodes got which workloads
kubectl get pods -o wide | grep demo

# Check GPU allocation per claim
kubectl get resourceclaims -o json | jq -r '.items[] | "\(.metadata.name): Node=\(.status.allocation.nodeSelector.nodeSelectorTerms[0].matchExpressions[0].values[0]) GPUs=\(.status.allocation.devices.results[].device)"'
```

## Step 10: ConfigMap-based Diff Transport

When you have local code changes, k8shazgpu packages them as a ConfigMap:

```bash
cd ~/vllm
sed -i -e 's/Hello, world!/KUBECON RULES!/' vllm/entrypoints/cli/main.py

# Create a workload (will auto-create ConfigMap)
k8shazgpu vllm run --name demo-diff --gpus 1 -- sleep 300

# Find the diff ConfigMap
kubectl get configmap | grep diff

# Inspect it
kubectl get configmap demo-diff-vllm-diff -o yaml
```

Look for:
- `data.diff` - Contains the git diff
- Annotations linking it to the ResourceClaim
- How the Pod mounts it

## Step 11: Observe DRA Device Preparation

Kubelet plugins prepare devices for pods. Check their logs:

```bash
# Find kubelet plugin pods
kubectl get pods -n canhazgpu-system -l app=canhazgpu-kubeletplugin

# Tail logs from one
kubectl logs -f -n canhazgpu-system canhazgpu-kubeletplugin-XXXXX
```

Look for:
- `PrepareResourceClaims` calls from kubelet
- CDI device ID construction
- Device preparation success/failure

## Step 12: Events and Troubleshooting

Check events to see DRA in action:

```bash
# Watch all events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Events for a specific ResourceClaim
kubectl describe resourceclaim demo

# Events for the Pod
kubectl describe pod demo-vllm-pod
```

Look for events like:
- ResourceClaim allocation
- Pod scheduling
- Volume mounting
- Container startup

## Step 13: Cleanup and Finalizers

Observe cleanup behavior:

```bash
# Watch ResourceClaims during deletion
kubectl get resourceclaims -w

# In another terminal, delete a workload
k8shazgpu cleanup --name demo

# Check finalizers on the ResourceClaim before deletion
kubectl get resourceclaim demo -o jsonpath='{.metadata.finalizers}'
```

The `canhazgpu.com/finalizer` ensures GPU deallocation happens before deletion completes.

## Step 14: Direct API Inspection (Advanced)

Use kubectl with custom columns to extract interesting DRA data:

```bash
# Custom columns for ResourceClaims
kubectl get resourceclaims -o custom-columns=\
NAME:.metadata.name,\
ALLOCATED:.status.allocation.devices.results[0].device,\
NODE:.status.allocation.nodeSelector.nodeSelectorTerms[0].matchExpressions[0].values[0]

# Show all ResourceSlices with device counts
kubectl get resourceslices -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
DRIVER:.spec.driver,\
DEVICES:.spec.devices[*].name
```

## Key Kubernetes Concepts Demonstrated

1. **DRA ResourceClaims** - The new way to request dynamic resources
2. **ResourceSlices** - How drivers advertise available devices
3. **CDI (Container Device Interface)** - Device exposure without env vars
4. **Finalizers** - Ensuring cleanup happens in the right order
5. **Custom Resources** - CachePlan and NodeCacheStatus for cache management
6. **DaemonSets** - Per-node components (kubelet plugin, node agent)
7. **Controller pattern** - Central allocator making scheduling decisions

## Questions to Explore

1. What happens if you delete a ResourceClaim while the Pod is running?
2. How does Kubernetes ensure Pods land on nodes with allocated GPUs?
3. What's in a ResourceSlice that's not in a Device Plugin?
4. How does the finalizer prevent resource leaks?
5. Can you create a ResourceClaim manually without k8shazgpu?

## Going Deeper

Check out `K8SHAZGPU_CODE_WALKTHROUGH.md` to see the code that makes all this work!
