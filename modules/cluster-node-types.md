# Cluster Node Types

Large production clusters typically have these types of nodes. In dev-clusters or small clusters, we might have a lead management node also perform the roles of user node and deployment node.

### 1. **C-mgmt Nodes (Control Management Nodes)**
- **Role:** These nodes run the Kubernetes control plane and other critical cluster management services.
- **Responsibilities:** 
  - Host Kubernetes components (apiserver, scheduler, etcd, etc.)
  - Run Ceph (for storage), Prometheus (monitoring), registry, nginx, cluster server, job operator, and other management services.
  - Provide high availability and redundancy for cluster management, especially in blue/green or rolling upgrade scenarios.
- **Separation:** In modern clusters (e.g., CG6 and onwards), C-mgmt nodes are distinct from D-mgmt nodes to avoid resource contention and improve reliability[1][2][3].

---

### 2. **D-mgmt Nodes (Coordinator Management Nodes)**
- **Role:** These nodes are primarily responsible for running ML workload coordination.
- **Responsibilities:**
  - Host coordinator pods for compile and execute jobs.
  - Handle log exports and some Ceph plugins (cephfs, rbd).
  - Serve as the main nodes for ML job orchestration, separate from the control plane.
- **Separation:** D-mgmt nodes are distinct from C-mgmt nodes in newer clusters, but in older clusters (like CG3), the same nodes might serve both roles[1][2][3].

---

### 3. **Deploy Node (Deployment Node)**
- **Role:** A specialized node used to drive cluster upgrades, deployments, and orchestration tasks.
- **Responsibilities:**
  - Hosts deployment packages and scripts.
  - Executes cluster upgrade and migration commands.
  - Often used as the entry point for cluster management tools (e.g., running `install.sh`, `csadm`, or `cscfg` commands).
  - May be required for blue/green upgrades to coordinate the migration of nodes between clusters[3][4].

---

### 4. **Other Node Types**
- **Worker Nodes:** Run user workloads (jobs, pods) and are managed by the control plane.
- **User Nodes:** Entry points for users to submit jobs, query status, and interact with the cluster.
- **Specialized Nodes:** Such as MemX, SwarmX, ActivationX, etc., each with hardware and software tailored for specific roles in the cluster[5][6].

---

### **How to Identify C-mgmt and D-mgmt Nodes**
- Use Kubernetes labels:
  - `kubectl get nodes -lk8s.cerebras.com/node-role-management` → shows C-mgmt nodes.
  - `kubectl get nodes -lk8s.cerebras.com/node-role-coordinator` → shows D-mgmt nodes[2][7].
