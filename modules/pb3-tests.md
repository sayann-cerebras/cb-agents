# Running PB3 Tests

`$GITTOP` is already set in the environment.

1. To run test, reuse a running cluster too. You can check if any cluster is running by running `docker ps --format '{{.Names}}' | grep -E 'pytest-[0-9]+-lb$' | sed 's/-lb$//'`. Use the cluster name with the flag `--use-cluster=<cluster-name>` to reuse the cluster. If there's no running cluster, skip this flag.

2. The `PB3_PKG` environment variable needs to be set to the name of the folder `find "$GITTOP/src/cluster_mgmt/src/cli" -type d -name 'cluster-package-*' -printf '%f\n'`

For example, to run the migration happy path test:

```sh
PB3_PKG=cluster-package-sayann-a313ba1d86 DB_UPDATE_ONLY=true $GITTOP/src/cluster_deployment/deployment/venv/bin/pytest -v -s --log-cli-level=INFO deployment_manager/tests_pb3/test_migration.py::test_migration_happy_path --keep-cluster=False
```
