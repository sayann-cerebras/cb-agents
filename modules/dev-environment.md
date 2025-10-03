# Dev Environment Access

For gathering information about the running status of the software that you will be working on, you can access the following clusters. You can ssh on the deploy node and check the active and standby clusters (blue green deployment) using `cscfg cluster show`. user is `root`. So use `ssh root@<node-name-or-ip>`, and prefer heredoc /multi-level heredoc in the ssh command. use `$(pass show ssh/cb)` to retrieve the password. Also, to prevent `password` prompts, ensure you do `ssh` in a way that tty is empty, and also ensure that prompts are not there during execution.

### Multibox-32 (aka MB-32)

  - `mb32-cs-wse004-us-sr01`: `Deploy node` and `User node`
  - `mb32-cs-wse001-mg-sr01`: Lead mgmt node of blue.
  - `mb32-cs-wse003-mg-sr02`: Lead mgmt node of green.

## Cluster bundles on deploy nodes
- Deploy node `root@mb32-cs-wse001-mg-sr01` keeps staged artifacts under `/root/sayann/Cluster/`.
- Extracting a top-level `Cluster-<ver>-<build>.tar.gz` yields several tarballs that map to build targets under `src/cluster_deployment`:
  * `cluster-package-…tar.gz` — output of `make package`; contains the deployment manager payload (Helm charts, manifests, orchestration scripts) consumed by `cscfg` during upgrades. This is the artifact you replace after local changes.
  * `cluster-deploy-…tar.gz` — deployment-node runtime (Python venv, ansible content, helper binaries) used while driving upgrades from the deploy host.
  * `cluster-client-…tar.gz` — client CLI bundle for user nodes; ships `cscfg`, `csadm`, and their Python dependencies to interact with management services.
  * `Cerebras-patches-…tar.gz` — patch payloads and supplementary configs that can be applied post-upgrade.
  * `CS1-…tar.gz` — legacy CS1 support artefacts retained for backwards compatibility.
- The umbrella `Cluster-…tar.gz` simply aggregates those subpackages plus release metadata (`release.json`, manifests). Re-running `make package` regenerates the `cluster-package-…tar.gz`; drop it into `/root/sayann/Cluster/` and reassemble if the top-level bundle is needed.

## Testing workflow (local → PB3 → real cluster)
1. **Unit tests (local)**
   - Run targeted `pytest` modules/functions for pure-Python logic.
   - Example: `pytest deployment_manager/tests/test_upgrade_planner.py::test_stage_plan`.
2. **PB3 tests (kind-backed)**
   - Set `PB3_PKG` to your local package directory:
     ```sh
     PB3_PKG=$(find "$GITTOP/src/cluster_mgmt/src/cli" -maxdepth 1 -type d -name 'cluster-package-*' -printf '%f\n')
     ```
   - Execute the desired scenario:
     ```sh
     PB3_PKG="$PB3_PKG" DB_UPDATE_ONLY=true \
       $GITTOP/src/cluster_deployment/deployment/venv/bin/pytest \
       -v -s --log-cli-level=INFO \
       deployment_manager/tests_pb3/test_migration.py::test_migration_happy_path --keep-cluster=False
     ```
   - PB3 exercises blue/green upgrade flows against kind clusters (skips heavyweight system upgrades).
3. **Sanity validation on a real cluster**
   - Build a fresh package: `make package` from `src/cluster_deployment`.
   - Copy the resulting `cluster-package-…tar.gz` to the deploy node using credentials from `$(pass show ssh/cb)`:
     ```sh
     scp build/output/cluster-package-<ver>.tar.gz \
         root@mb32-cs-wse001-mg-sr01:/root/sayann/Cluster/
     ```
   - On the deploy node, unpack within `/root/sayann/Cluster/`, then run `cscfg cluster upgrade create` followed by `cscfg cluster upgrade prepare-data`.
   - For Grafana dashboard validation:
     ```sh
     kubectl -n grafana-blue port-forward svc/grafana 3000:80 --address 0.0.0.0
     kubectl -n grafana-green port-forward svc/grafana 3001:80 --address 0.0.0.0
     ```
     Browse both endpoints to ensure new dashboards appear on green after `prepare-data`.
   - Document the exact manual checks and shut down any port-forward sessions when finished.

