# Nomad Cluster Configuration

This directory contains configuration relating to the configuration of the cluster including:
- node pools
- agent config

## Node Pools

[Node pools](https://developer.hashicorp.com/nomad/docs/concepts/node-pools) are a way to group nodes together into logical groups which jobs can target that can be used to enforce where allocations are placed.

e.g. [`ingress-pool.hcl`](./ingress-pool.hcl) is a node pool that is used for ingress nodes such as the [bastion-vm](https://docs.redbrick.dcu.ie/aperture/bastion-vm/). Any jobs that are defined to use `node_pool = "ingress"` such as `traefik.hcl` and `gate-proxy.hcl` will only be assigned to one of the nodes in the `ingress` node pool (i.e. the [bastion VM](https://docs.redbrick.dcu.ie/aperture/bastion-vm/))
