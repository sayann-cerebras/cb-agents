# Dev Environment Access

For gathering information about the running status of the software that you will be working on, you can access the following clusters. You can ssh on the deploy node and check the active and standby clusters (blue green deployment) using `cscfg cluster show`. user is `root`. So use `ssh root@<node-name-or-ip>`, and prefer heredoc /multi-level heredoc in the ssh command. use `$(pass show ssh/cb)` to retrieve the password. Also, to prevent `password` prompts, ensure you do `ssh` in a way that tty is empty, and also ensure that prompts are not there during execution.

### Multibox-32 (aka MB-32)

  - `mb32-cs-wse004-us-sr01`: `Deploy node` and `User node`
  - `mb32-cs-wse001-mg-sr01`: Lead mgmt node of blue.
  - `mb32-cs-wse003-mg-sr02`: Lead mgmt node of green.
