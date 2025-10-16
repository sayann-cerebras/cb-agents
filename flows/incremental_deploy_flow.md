# Incremental Deploy Flow

## Detection & Planning
- [`apps/csadm/csadm/csadm_list_helper.py`][^1] diffs `network_config.json` against the live `cluster.yaml`, writes node/system add-remove lists, and emits a merged `incremental-cluster.yaml` plus per-node metadata files inside `INCREMENTAL_DIR`.
- [`apps/csadm/csadm.sh`][^2] consumes those lists to decide whether to run in incremental mode, labels fresh nodes `cerebras/incremental-new` before component installs, and reconciles `cluster.yaml`/ConfigMaps once deployment succeeds.

## Shared Helper Behavior
- [`apps/common/pkg-common.sh`][^3] exposes `is_incremental_deploy` and skips generating global node lists during incremental runs.
- [`apps/common/pkg-functions/nodes.sh`][^4] repoints every list (pssh targets, mgmt/worker subsets, unreachable nodes) to the incremental files so downstream scripts naturally scope operations to the new hosts.
- [`apps/common/pkg-functions/images.sh`][^5] constrains image-preload DaemonSets with the `cerebras/incremental-new` selector so only freshly added nodes pull required images.

## Kubernetes Bootstrap
- [`apps/k8s/setup.sh.jinja2`][^6] applies the standard management/coordinator labels and, when incremental, labels just the new broadcast-reduce nodes before exiting early.
- [`apps/k8s/k8_init.sh`][^7] derives add/remove/update host lists from the incremental artifacts, ensuring kubeadm reconciliation targets only nodes that changed.

## Core Node Prep & Networking
- [`apps/binary-deps/install.sh.jinja2`][^8] falls back to copying binaries directly to the incremental node list instead of re-running the full installer.
- [`apps/registry/install.sh.jinja2`][^9] updates containerd certificates via PSSH and skips reapplying the daemonset when incremental mode is active.
- [`apps/multus/net-attach-def.sh`][^10] limits rsync + installer execution to the new nodes, short-circuits after syncing configs, and loads incremental artifacts onto remote hosts.
- [`apps/multus/net-attach-def-installer.sh`][^11] mirrors the incremental directory to each worker before regenerating node-specific configs.
- [`apps/rdma-device-plugin/rdma-device-plugin.sh.jinja2`][^12] swaps to incremental test daemonsets so validation only touches nodes labeled `cerebras/incremental-new`.
- [`apps/cilium/helm-upgrade.sh.jinja2`][^13] skips reinstalling the CLI binary during incremental upgrades while still patching resources and tolerating unreachable new nodes.
- [`apps/nginx/helm-upgrade.sh.jinja2`][^14] patches service external IPs, replicas, and restarts only impacted pods, exiting once the incremental adjustments succeed.
- [`apps/kube-vip/helm-upgrade.sh.jinja2`][^15] is marked `SKIP_IF_INCREMENTAL`, so full VIP setup is deferred until a non-incremental deploy.
- [`apps/multus/multus.sh.jinja2`][^16] likewise opts out during incremental cycles to avoid re-rolling the base CNI stack.

## Storage & Observability
- [`apps/ceph/helm-upgrade.sh.jinja2`][^17] only patches resource limits, PVC sizing, and CSI labels when running incrementally.
- [`apps/log-scraping/helm-upgrade.sh.jinja2`][^18] prepares storage on single-mgmt clusters and exits early otherwise.
- [`apps/prometheus/helm-upgrade.sh.jinja2`][^19] patches resource requests/limits, retention settings, and performs optional storage migrations without reinstalling the chart.
- [`apps/cpingmesh/cpingmesh-deploy.sh.jinja2`][^20] simply recycles unhealthy agent pods on new nodes while leaving the broader control plane untouched.

[^1]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/csadm/csadm/csadm_list_helper.py#L50-L262
[^2]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/csadm/csadm.sh#L1840-L2094
[^3]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/common/pkg-common.sh#L50-L91
[^4]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/common/pkg-functions/nodes.sh#L3-L20
[^5]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/common/pkg-functions/images.sh#L132-L216
[^6]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/k8s/setup.sh.jinja2#L1-L45
[^7]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/k8s/k8_init.sh#L124-L165
[^8]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/binary-deps/install.sh.jinja2#L43-L53
[^9]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/registry/install.sh.jinja2#L33-L53
[^10]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/multus/net-attach-def.sh#L42-L123
[^11]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/multus/net-attach-def-installer.sh#L29-L36
[^12]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/rdma-device-plugin/rdma-device-plugin.sh.jinja2#L26-L69
[^13]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/cilium/helm-upgrade.sh.jinja2#L67-L127
[^14]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/nginx/helm-upgrade.sh.jinja2#L74-L157
[^15]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/kube-vip/helm-upgrade.sh.jinja2#L1-L160
[^16]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/multus/multus.sh.jinja2#L1-L110
[^17]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/ceph/helm-upgrade.sh.jinja2#L76-L81
[^18]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/log-scraping/helm-upgrade.sh.jinja2#L13-L18
[^19]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/prometheus/helm-upgrade.sh.jinja2#L181-L204
[^20]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_mgmt/src/cli/apps/cpingmesh/cpingmesh-deploy.sh.jinja2#L9-L28
