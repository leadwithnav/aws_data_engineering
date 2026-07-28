# Lab Guide: Amazon EKS Cluster Architecture, Node Group Strategies & Autoscaling

Welcome to **Lab 16: Amazon EKS Cluster Architecture, Node Group Strategies, Autoscaling Architecture & EKS Auto Mode**. 

This comprehensive reference guide provides a deep-dive architectural breakdown of Amazon EKS, covering control plane management, multi-tenant namespace governance, specialized node group strategies, horizontal/vertical autoscaling loops, EKS Auto Mode, and AWS Management Console node group operations.

---

## 1. Amazon EKS Shared Cluster Architecture

Amazon EKS follows a **Shared Cluster Model** that decouples AWS-managed control plane components from customer-managed worker node infrastructure and tenant namespaces.

```mermaid
graph TD
    subgraph Control Plane (AWS Managed)
        API[API Server] --- SCHED[Kube Scheduler]
        API --- CM[Controller Manager]
        API --- ETCD[(etcd Database)]
    end

    subgraph Tenant Namespaces (Logical Isolation)
        direction LR
        subgraph Tenant A
            TA[App A1 / App A2]
            TA_Q[Resource Quota & Network Policy]
        end
        subgraph Tenant B
            TB[App B1 / App B2]
            TB_Q[Resource Quota & Network Policy]
        end
        subgraph Tenant C
            TC[App C1 / App C2]
            TC_Q[Resource Quota & Network Policy]
        end
        subgraph Tenant N
            TN[App N1 / App N2]
            TN_Q[Resource Quota & Network Policy]
        end
    end

    subgraph Shared Cluster Services
        DNS[CoreDNS]
        PROXY[Kube-Proxy]
        CNI[VPC CNI Plugin]
        MS[Metrics Server]
        CA[Cluster Autoscaler]
        ING[Ingress Controller]
    end

    subgraph Worker Node Groups (Shared Infrastructure)
        NG1[Compute Node Group]
        NG2[Memory Optimized Node Group]
        NG3[Spot Node Group]
    end

    API --> Tenant A
    API --> Tenant B
    API --> Tenant C
    API --> Tenant N
    Shared Cluster Services --> Worker Node Groups
```

### Architectural Layer Breakdown

| Layer | Components | Responsibility & Governance |
| :--- | :--- | :--- |
| **AWS Managed Control Plane** | API Server, Kube-Scheduler, Controller Manager, `etcd` | High-availability control plane distributed across 3 AWS Availability Zones (AZs). Managed automatically by AWS with SLA guarantees. |
| **Tenant Namespaces** | `Tenant A`, `Tenant B`, `Tenant C` ... `Tenant N` | Virtual partitioning providing logical multi-tenancy. Enforces `ResourceQuota` (CPU/RAM caps) and `NetworkPolicy` (microservice isolation). |
| **Shared Cluster Services** | CoreDNS, Kube-Proxy, AWS VPC CNI, Metrics Server, Cluster Autoscaler, Ingress Controller | System add-ons providing pod networking, internal DNS, metrics collection, ingress routing, and node autoscaling. |
| **Worker Node Groups** | Compute, Memory-Optimized, and Spot EC2 Auto Scaling Groups | Shared compute capacity running application pods with auto-scaling, self-healing, and mixed instance type capabilities. |

---

## 2. Worker Node Group Strategies

To optimize cost, performance, and resilience, EKS workloads are segmented across three distinct Node Group Strategies:

```
+---------------------------------------------------------------------------------------------------+
|                                  EKS NODE GROUP STRATEGIES                                         |
+-----------------------------------+-----------------------------------+---------------------------+
| 1. COMPUTE NODES                  | 2. MEMORY OPTIMIZED NODES         | 3. SPOT NODES             |
| General Purpose Workloads         | Memory Intensive Workloads        | Cost-Optimized Capacity   |
+-----------------------------------+-----------------------------------+---------------------------+
| Instance Families:                | Instance Families:                | Instance Families:        |
| m6i, m6a, m7i, c6i, c6a, c7i      | r6i, r6a, r7i, x2idn, x2iedn      | Mixed Instance Families   |
+-----------------------------------+-----------------------------------+---------------------------+
| Ideal For:                        | Ideal For:                        | Ideal For:                |
| • Stateless Microservices         | • In-Memory Databases (Redis)     | • Spark / Flink ETL Jobs  |
| • Web Servers & REST APIs         | • Distributed Caching (Memcached) | • Batch Data Processing   |
| • CI/CD Runners & Backend Services| • Real-Time Analytics & Streaming | • Resilient ML Training   |
+-----------------------------------+-----------------------------------+---------------------------+
| Key Characteristics:              | Key Characteristics:              | Key Characteristics:      |
| ✔ Balanced CPU, Memory & Network  | ✔ High RAM-to-vCPU Ratio          | ✔ 70% to 90% Cost Savings |
| ✔ Predictable On-Demand Pricing   | ✔ In-Memory Dataset Processing    | ✔ Interruptible Capacity  |
+-----------------------------------+-----------------------------------+---------------------------+
```

### Detailed Strategy Comparison

| Feature / Metric | 1. Compute Nodes | 2. Memory-Optimized Nodes | 3. Spot Nodes |
| :--- | :--- | :--- | :--- |
| **Typical EC2 Families** | `m6i`, `m6a`, `m7i`, `c6i`, `c6a`, `c7i` | `r6i`, `r6a`, `r7i`, `x2idn`, `x2iedn` | Mixed Families (`m5`, `m6i`, `c5`, `r5`) |
| **Primary Use Cases** | Microservices, REST APIs, Web Servers | Redis, Memcached, Kafka, Spark, Elasticsearch | Apache Spark, Batch Processing, ML Training |
| **Capacity Type** | On-Demand | On-Demand | Spot (Interruptible by AWS) |
| **Cost Savings** | Baseline Standard Pricing | Standard High-Memory Pricing | **70% to 90% Savings vs On-Demand** |
| **Fault Tolerance** | Standard EC2 SLA | Standard EC2 SLA | Requires fault-tolerant/retryable workloads |

---

## 3. EKS Autoscaling Architecture

EKS autoscaling combines pod-level scaling (**Horizontal Pod Autoscaler - HPA**) and node-level scaling (**Cluster Autoscaler** / **Karpenter**) in a synchronized 4-step loop.

```mermaid
graph TD
    subgraph Workload Ingestion
        USER[Users / Clients] --> ALB[Application Load Balancer / Ingress]
        ALB --> SVC[Kubernetes Service]
        SVC --> PODS[Application Workloads / Pods]
    end

    subgraph Kubernetes Add-ons
        MS[Metrics Server]
        CA[Cluster Autoscaler / Karpenter]
        SCHED[Kube Scheduler]
    end

    subgraph Node Groups (Managed by Cluster Autoscaler)
        NG_COMP[Compute Node Group<br/>Min: 1 | Desired: X | Max: N]
        NG_MEM[Memory Node Group<br/>Min: 1 | Desired: X | Max: N]
        NG_SPOT[Spot Node Group<br/>Min: 0 | Desired: X | Max: N]
    end

    PODS -.->|Resource Metrics| MS
    MS -.->|Evaluates CPU/RAM| CA
    CA -->|Scales Node Capacity| NG_COMP
    CA -->|Scales Node Capacity| NG_MEM
    CA -->|Scales Node Capacity| NG_SPOT
```

### The 4-Step Autoscaling Loop

```
   +--------------------+      +--------------------+      +--------------------+      +--------------------+
   | 1. OBSERVE METRICS | ---> | 2. EVALUATE DEMAND | ---> | 3. TAKE ACTION     | ---> | 4. STABILIZE       |
   | CPU, Memory, Queue |      | HPA & Cluster      |      | Scale Pods (HPA)   |      | Maintain Desired   |
   | Utilization        |      | Autoscaler Review  |      | Scale Nodes (CA)   |      | State within Bounds|
   +--------------------+      +--------------------+      +--------------------+      +--------------------+
```

1. **Step 1: Observe Metrics**: Metrics Server continuously harvests CPU, Memory, and custom application metrics across all running pods.
2. **Step 2: Evaluate Demand**:
   - **HPA** checks if pod CPU/RAM exceeds target utilization thresholds (e.g. > 70%).
   - **Cluster Autoscaler** checks if pods are stuck in `Pending` state due to insufficient cluster node capacity.
3. **Step 3: Take Action**:
   - **HPA** increases desired pod replica count.
   - **Cluster Autoscaler** expands EC2 Auto Scaling Group limits (increasing `Desired` capacity) or provisions new nodes.
4. **Step 4: Stabilize**: Once new nodes join the cluster and pods transition to `Running`, metrics stabilize within specified `Min` and `Max` boundary limits.

---

## 4. EKS Control Plane Settings & EKS Auto Mode

AWS provides advanced options to manage EKS control planes and node automation directly within the AWS Management Console:

### 4.1 EKS Auto Mode
- **Overview**: AWS-managed compute mode where AWS automatically handles routine cluster tasks for compute provisioning, storage volume attachment, and networking.
- **Benefits**: Eliminates manual node group configuration, automatically selects optimal EC2 instance types, and continuously applies security patches.
- **State Options**: `Enabled` or `Disabled`.

### 4.2 Control Plane Scaling Tiers
- **Standard Tier**: Control plane resources scale dynamically based on cluster API traffic and node count. Ideal for general production workloads.
- **Pre-Provisioned High-Performance Tiers**: Pre-provisions control plane infrastructure with fixed high-performance resources. Eliminates control plane scaling latency during massive traffic spikes or large-scale batch processing.

### 4.3 Kubernetes Version & Extended Support
- **Standard Support**: Full AWS support for active Kubernetes minor releases (14 months).
- **Extended Support**: Automatically extends support for older Kubernetes minor versions (up to 26 months), allowing enterprise compliance while upgrading on scheduled cycles.

---

## 5. Console Guide: Managing Node Groups & Fargate Profiles

### 5.1 Managed Node Groups vs. Fargate Profiles

| Compute Option | Management Overhead | Customization | Best For |
| :--- | :--- | :--- | :--- |
| **Managed Node Groups** | AWS manages EC2 provisioning, AMI updates, and scaling via EC2 Auto Scaling Groups. | Full control over EC2 instance families, launch templates, custom AMIs, and disk sizing. | General workloads, DaemonSets, GPU nodes, Spark workers. |
| **Fargate Profiles** | Serverless compute. AWS manages underlying microVM infrastructure automatically. | Zero EC2 configuration. Pods specify CPU/Memory requests. | Event-driven microservices, isolated job executions, low-maintenance API pods. |

### 5.2 Step-by-Step AWS Console Walkthrough: Adding a Managed Node Group

1. **Navigate to EKS Console**: Open AWS Console -> **Amazon EKS** -> **Clusters** -> Select your cluster (e.g. `spark-eks-cluster`).
2. **Open Compute Tab**: Click on the **Compute** tab.
3. **Add Node Group**: Under the **Node groups** section, click **Add node group**.
4. **Configure Node Group Name & IAM Role**:
   - Enter **Node group name** (e.g. `memory-node-group` or `spot-node-group`).
   - Select the **Node IAM Role** (with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`).
5. **Set Compute Configuration**:
   - **AMI Type**: Amazon Linux 2 or Bottlerocket.
   - **Capacity Type**: Choose `On-Demand` or `Spot`.
   - **Instance Types**: Select families (e.g. `r6i.large` for memory or `m6i.large`, `c6i.large` for spot).
6. **Set Scaling Configuration**:
   - **Minimum size**: `1`
   - **Maximum size**: `5`
   - **Desired size**: `2`
7. **Review and Create**: Review settings and click **Create**. AWS automatically provisions the EC2 Auto Scaling Group and registers worker nodes with your EKS cluster.
