# Proxbox Kube

## Goal

The goal of this project is to automate standing up and tearing down a kubernetes cluster. 
- Nodes are provisioned from proxmox via Terraform 
- Cloud init configueres basics of the nodes like ports, swap, ssh keys, and preps to pass over to Ansible
- Ansible handles initializing, joining, and configuring the cluster.

## Notes and Learnings

### Proxmox Output formats

By default, proxmox cli stuff tends to output things in "human readable text tables"
which look like this

┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ tform_user@pve!test2                 │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":1}                        │
├──────────────┼──────────────────────────────────────┤
│ value        │ 24e01abd-3421-4a83-aad1-b12a42c6fcb7 │
└──────────────┴──────────────────────────────────────┘

These aren't great for automating, but you can pass other formats!

example: pveum token add "tform_user@pve" token_name --output-format=json
    - easy to use with jq or something
example plain text but no borders: pveum token add "tform_user@pve" token_name --noborder=1 --noheader=1
    - this example is much easier to awk 

https://github.com/proxmox/pve-docs/blob/5b4f68560624dae0342e55816f51dc6b47b5a2a3/output-format-opts.adoc

