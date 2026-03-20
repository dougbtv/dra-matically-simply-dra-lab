# GPU Workflows with DRA

In this workshop we will explore **three perspectives** on GPU usage:

| Role                 | What they care about                                  |
| -------------------- | ----------------------------------------------------- |
| **Data Scientist**   | “I just need a GPU for my process.”                   |
| **vLLM Developer**   | “Run my code on GPUs at cluster scale.”               |
| **Kubernetes Admin** | “How does Kubernetes schedule and manage these GPUs?” |

Each role interacts with the system differently.

---

# 0. Login to your workshop environment

After completing the **Google Form signup**, you will receive a shell account.

SSH into the workshop host:

```
ssh <your-github-username>@OUR.TBD.IP.ADDRESS
```

Example:

```
ssh dougsmith@OUR.TBD.IP.ADDRESS
```

Once logged in you will have:

* Access to **GPU nodes**
* The **canhazgpu (`chg`) CLI**
* The **k8shazgpu CLI**
* `kubectl` configured for the cluster

---

# 1. Using GPUs as a Data Scientist

As a data scientist, you usually only care about one thing:

> **“I need a GPU for my process.”**

Traditionally this means **reserving a GPU on a shared machine** and running workloads manually.

This works — but it doesn't scale well.

To simulate this workflow we use **canhazgpu (`chg`)**.

---

## Run a process on your reserved GPU

You might run something long-lived.

Example:

```
tmux -S chg
canhazgpu run -- sleep 100
```

Detach from the session:

```
Ctrl-b d
```

Check status again:

```
chg status
```

You now have a GPU **reserved and occupied**.

## Manual GPU reservation with `canhazgpu` (optional!)

Reserve a GPU for 5 minutes:

```
chg reserve d 5m
```

It'll say you need to set an env var (you can ignore it)

Check your reservation:

```
chg status
```

And then you can release it:

```
chg release
```


---

# 2. Using GPUs as a vLLM Developer

Now let's switch roles.

As a **vLLM developer**, you care about:

* your **code**
* your **results**

You **do not want to write Kubernetes YAML**.

Instead we use **k8shazgpu**, which automatically:

* builds the environment
* schedules GPU workloads
* allocates GPUs using **DRA**

---

## Explore the repository

A clone of `vllm` is already available.

```
cd ~
cd vllm
```

Inspect the repository:

```
git remote
git branch -v
```

---

## Look at the change we made

We modified a small piece of code.

```
git diff HEAD~1..HEAD
```

The change is in:

```
vllm/entrypoints/cli/main.py
```

You can modify this message yourself.

For example, change the message to something fun.

---

## Run vLLM on the cluster

Launch the workload:

```
k8shazgpu vllm run --follow --name vllm-demo -- vllm serve
```

This command will:

* build a workload
* allocate GPUs via **DRA**
* schedule it onto the cluster

You should eventually see the output:

```
Hello, world!
```

## Observe the cluster

Even though this workflow feels local, the GPUs still exist on Kubernetes nodes.

You can inspect the cluster:

```
kubectl get nodes
kubectl get pods -A
```

Notice where workloads are running.

---

## Inspect the workload

In another terminal you can inspect logs manually:

```
kubectl logs -f vllm-demo-vllm-pod -n default
```

---

## Before cleaning up — look at the GPU allocation

This is the key moment where **DRA becomes visible**.

List ResourceClaims:

```
kubectl get resourceclaims -A
```

Inspect the claim created for your job:

```
kubectl describe resourceclaims vllm-demo
```

This shows how Kubernetes allocated the GPUs.

---

## Clean up the workload

When you're done:

```
k8shazgpu cleanup --name vllm-demo
```

Check GPU usage:

```
k8shazgpu status
```

---

## Try modifying the code

Edit the message in `main.py`.

For example:

```
buy more ovaltine!
```

Run the job again:

```
k8shazgpu vllm run --follow --name $(whoami)-vllm-demo -- vllm serve
```

You should now see your new output.

When you're done! ...you can clean it up, but, I'd wait until you're done

```
k8shazgpu cleanup --name $(whoami)-vllm-demo
```

---

# 3. Viewing the system as a Kubernetes Admin

Now we switch roles again.

As a **Kubernetes admin**, you care about:

* scheduling
* resource allocation
* cluster behavior

Specifically, you want to see **how GPUs are allocated through DRA**.

---

## Inspect ResourceClaims

List all GPU claims:

```
kubectl get resourceclaims -A
```

Inspect a specific claim:

```
kubectl describe resourceclaims vllm-demo
```

Look for:

* allocated GPU devices
* node placement
* scheduling status

---

## Observe running workloads

Check running pods:

```
kubectl get pods -A
```

Inspect node placement:

```
kubectl get pods -o wide
```

# Optional but, AWESOME steps.

## Observe DRA Device Preparation

Kubelet plugins prepare devices for pods. Check their logs:

```bash
# Find your pod...
kubectl get pods -o wide

# Find kubelet plugin pods
kubectl get pods -n canhazgpu-system -l app=canhazgpu-kubeletplugin -o wide

# Tail logs from the same node...
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

## Cleanup and Finalizers

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

---

# Summary

In this lab we explored **three GPU workflows**:

| Role             | Tool        | Model                        |
| ---------------- | ----------- | ---------------------------- |
| Data Scientist   | `canhazgpu` | Manual GPU reservation       |
| vLLM Developer   | `k8shazgpu` | Automated cluster scheduling |
| Kubernetes Admin | `kubectl`   | Observing DRA in action      |

DRA allows GPUs to be **allocated dynamically by Kubernetes**, enabling scalable GPU scheduling without forcing developers to understand Kubernetes internals.
