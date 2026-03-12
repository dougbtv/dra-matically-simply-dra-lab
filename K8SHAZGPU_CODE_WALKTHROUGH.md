# k8shazgpu Code Walkthrough

A guide for KubeCon attendees exploring how k8shazgpu implements GPU scheduling using Kubernetes Dynamic Resource Allocation (DRA).

## What is k8shazgpu?

k8shazgpu brings the simplicity of `canhazgpu` (single-host GPU reservation) to Kubernetes clusters using **Dynamic Resource Allocation (DRA)**. It allows developers to run GPU workloads without writing YAML, while Kubernetes handles scheduling and resource management under the hood.

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  k8shazgpu CLI  │────>│ ResourceClaim     │────>│  DRA Controller │
│  (User facing)  │     │ (GPU request)     │     │  (Allocator)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                           │
                        ┌──────────────────────────────────┘
                        │
                        v
              ┌─────────────────┐     ┌─────────────────┐
              │ Kubelet Plugin  │────>│   Node Agent    │
              │ (Device prep)   │     │ (Cache + Redis) │
              └─────────────────┘     └─────────────────┘
```

## Key Components to Explore

### 1. CLI Entry Point

**File:** `cmd/k8shazgpu/main.go`

Simple entry point that delegates to the CLI implementation. Start here to understand the tool's structure.

```go
func main() {
    if err := k8scli.Execute(); err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
}
```

### 2. DRA Controller (GPU Allocator)

**File:** `driver/dra/controller/controller.go`

The heart of DRA integration. This controller watches for `ResourceClaim` objects and allocates GPUs.

**Key functions:**
- `Reconcile()` - Main reconciliation loop (lines 36-101)
- `allocateResources()` - Selects nodes and requests GPU allocation (lines 103-180)
- `requestAllocationFromNode()` - Communicates with node agent via HTTP (lines 280-335)

**What to look for:**
- How ResourceClaims are converted to GPU allocations
- Node selection strategy (currently simple: any ready node)
- Communication between controller and node agents
- Finalizer handling for cleanup on deletion

### 3. Kubelet Plugin (DRA Device Preparation)

**File:** `driver/dra/kubeletplugin/driver.go`

Implements the DRA kubelet plugin interface. This is what prepares GPUs for pods.

**Key functions:**
- `NewDriver()` - Initializes plugin and publishes device resources (lines 24-70)
- `PrepareResourceClaims()` - Called by kubelet to prepare devices for pods (lines 79-134)
- Device publishing using `resourceslice.DriverResources` (lines 46-63)

**What to look for:**
- How GPU devices are published to Kubernetes
- CDI (Container Device Interface) device references
- Integration with kubelet's DRA framework

### 4. Node Agent (Cache + GPU Management)

**File:** `driver/dra/nodeagent/main.go`
**File:** `driver/dra/nodeagent/cache.go`

Runs on each node to manage GPU allocations via Redis and handle resource caching.

**Key functions:**
- `handleAllocation()` - Allocates GPUs using Redis (nodeagent/main.go:150-200)
- `handleDeallocation()` - Releases GPUs (nodeagent/main.go:202-230)
- `SimpleCacheReconciler.Reconcile()` - Pulls images, clones repos, downloads models (cache.go:38-62)

**What to look for:**
- Redis integration for GPU state management
- HTTP API for controller communication
- Cache reconciliation loop (images, git repos, models)
- NodeCacheStatus CRD updates

### 5. vLLM Integration

**File:** `internal/k8scli/vllm.go`
**File:** `internal/k8scli/vllm_checkout.go`

The "magic" that makes local development feel seamless.

**Key functions:**
- `detectVLLMCheckout()` - Detects if you're in a vLLM git checkout (vllm_checkout.go:32-73)
- `createDiffConfigMap()` - Packages local changes for transport to cluster (vllm_checkout.go:250-350)
- `vllmRunCmd.RunE()` - Creates ResourceClaim with vLLM annotations (vllm.go:35-238)

**What to look for:**
- Git checkout detection and merge-base calculation
- Diff generation and ConfigMap creation
- Cache validation and warming before GPU allocation
- Automatic image/repo selection based on checkout

### 6. Cache Management

**File:** `internal/k8scli/cache.go`

Commands for managing cached resources across the cluster.

**Key functions:**
- `addCacheItem()` - Adds images/repos/models to cache plan (lines 200-350)
- `showCacheStatus()` - Displays per-node cache status (lines 450-550)
- `waitForCacheReady()` - Waits for resources to be cached (lines 600-700)

**What to look for:**
- CachePlan and NodeCacheStatus CRD interactions
- Real-time progress streaming from node agents
- Cache validation before workload launch

## DRA Concepts in Action

### ResourceClaim Lifecycle

1. **Creation** - CLI creates ResourceClaim with GPU count/IDs
2. **Allocation** - Controller selects node and allocates GPUs
3. **Preparation** - Kubelet plugin prepares devices using CDI
4. **Usage** - Pod runs with GPUs available via CDI
5. **Cleanup** - Finalizer ensures GPU deallocation on deletion

**See it in code:**
- Creation: `pkg/k8s/client.go` - `CreateResourceClaimWithVLLMAnnotations()`
- Allocation: `driver/dra/controller/controller.go` - `allocateResources()`
- Preparation: `driver/dra/kubeletplugin/driver.go` - `PrepareResourceClaims()`

### Why DRA Matters

Traditional GPU scheduling in Kubernetes uses device plugins with:
- Static device enumeration
- Limited flexibility in allocation
- No dynamic resource discovery

DRA provides:
- **Dynamic allocation** - Resources allocated at pod scheduling time
- **Structured parameters** - Rich resource requests beyond simple counts
- **Flexible preparation** - Driver controls how devices are prepared
- **Better multi-tenancy** - Fine-grained control over resource sharing

**See it in code:**
- Device publishing: `driver/dra/kubeletplugin/driver.go:46-63`
- Dynamic allocation: `driver/dra/controller/controller.go:103-180`

## Hands-On Exploration

### 1. Watch ResourceClaim creation

```bash
# In one terminal
kubectl get resourceclaims -A -w

# In another terminal
k8shazgpu vllm run --name demo --gpus 1 -- sleep 300
```

### 2. Inspect the DRA objects

```bash
kubectl describe resourceclaim demo
kubectl get resourceslices
```

### 3. See cache reconciliation in action

```bash
# Watch node agent logs
kubectl logs -f -n canhazgpu-system -l app=canhazgpu-nodeagent

# Add a new cache item
k8shazgpu cache add image redis:latest
```

### 4. Trace a complete allocation

```bash
# Controller logs (allocation decision)
kubectl logs -f -n canhazgpu-system -l app=canhazgpu-controller

# Kubelet plugin logs (device preparation)
kubectl logs -f -n canhazgpu-system -l app=canhazgpu-kubeletplugin

# Node agent logs (GPU state changes)
kubectl logs -f -n canhazgpu-system -l app=canhazgpu-nodeagent
```

## Key Takeaways

1. **DRA is a three-part dance**: Controller allocates, kubelet plugin prepares, workload consumes
2. **ResourceClaims are the contract**: They represent GPU requests and track allocation state
3. **CDI provides the device abstraction**: GPUs are exposed via Container Device Interface
4. **Redis bridges DRA and canhazgpu**: Node agents use Redis for GPU state, matching canhazgpu's model
5. **Cache pre-warming is critical**: Node agents ensure images/repos/models are ready before allocation

## Further Reading

- [Kubernetes DRA Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
- [Container Device Interface (CDI)](https://github.com/cncf-tags/container-device-interface)
- [DRA Example Driver](reference/dra-example-driver/) - Reference implementation in this repo
- [canhazgpu Architecture](docs/dev-architecture.md) - Single-host GPU management background

## Questions to Explore

1. How would you modify the node selection strategy in the controller?
2. What would it take to support GPU sharing (multiple pods per GPU)?
3. How could you add priority-based allocation?
4. What happens if a node agent crashes during allocation?
5. How would you implement GPU topology awareness?

Happy exploring!
