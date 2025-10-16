# Upgrade Cluster Failure Flow Notes

## Security Patch Stage
- `_security_patch_servers` categorizes each node using `UpdateStatus` enums after the patch run, logging successes, failures, unreachables, and unknowns.[^1]
- `update_servers` executes the underlying Ansible playbook, parses results into the same `UpdateStatus` values, and records the per-category counts.[^2]
- `UpdateStatus` definitions (`OK`, `FAILED`, `UNREACHABLE`) live here.[^3]
- Batch migration updates device states based on those enums via `update_security_patch_status`, mapping to `UpgradeDeviceStatus` values such as `security_patch_failed`/`security_patch_unknown_error`.[^4]
- The batch controller integrates the security patch step and currently raises on any non-success, requiring `--force` for retries.[^5]

## `csadm install` Stage
- `upgrade_pb3` runs `./csadm.sh install` on the management node and returns a `(success, message)` tuple, deleting retry manifests on success; failures only surface as free-form strings today.[^6]
- `ClusterUpgradeDestClusterCmd` consumes that tuple, logging the failure reason, marking `UpgradeProcessStatus.FAILED`, and ending the step for observability.[^7]
- Direct CLI invocation (`update_cluster_pkg`) behaves similarly—non-zero exit raises a `RuntimeError`, and callers just log the exception text.[^8]
- Top-level process states (currently falling back to a single `FAILED` state) are defined here, highlighting where finer-grained failure enums would plug in.[^9]

[^1]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cluster/helpers.py#L442-L456
[^2]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cluster_platform/update_servers.py#L312-L520
[^3]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cluster_platform/update_status.py#L1-L8
[^4]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cluster/helpers.py#L578-L603
[^5]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cluster/batch.py#L1154-L1169
[^6]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cluster/helpers.py#L358-L404
[^7]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cluster/upgrade.py#L662-L713
[^8]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/cli/cmd_cluster_mgmt.py#L160-L207
[^9]: https://github.com/Cerebras/monolith/tree/e76831e265e4ed6e4896f71834da72ed66eac253/src/cluster_deployment/deployment/deployment_manager/db/models.py#L46-L84
