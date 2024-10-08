# User VMs

For the latest docs, see [here](https://docs.redbrick.dcu.ie/services/user-vms/).

User VMs are deployed on [`aperture`](https://docs.redbrick.dcu.ie/hardware/aperture/) using [nomad](https://docs.redbrick.dcu.ie/services/nomad/)'s [QEMU driver](https://developer.hashicorp.com/nomad/docs/drivers/qemu).

Each VM is configured with cloud-init. Those configuration files are served by [`wheatley`](https://docs.redbrick.dcu.ie/hardware/aperture/wheatley/), but they can be served by any HTTP server.

## Setting up Networking on the Host

The host needs to be configured to allow the VMs to communicate with each other. This is done by creating a bridge and adding the VMs to it.

### Create a Bridge

To create a bridge that qemu can use to place the guest (VM) onto the same network as the host, follow the instructions listed [here](https://wiki.archlinux.org/title/Network_bridge#With_iproute2) for `iproute2`, summarised below.

We need to create a bridge interface on the host.

```bash
sudo ip link add name br0 type bridge
sudo ip link set dev br0 up
```

We'll be adding a physical interface to this bridge to allow it to communicate with the external ([UDM](https://docs.redbrick.dcu.ie/hardware/network/mordor/)) network.

```bash
sudo ip link set eno1 master br0
```

You'll need to assign an IP address to the bridge interface. This will be used as the default address for the host. You can do this with DHCP or by assigning a static IP address. The best way to do this is to create a DHCP static lease on the [UDM](https://docs.redbrick.dcu.ie/hardware/network/mordor/) for the bridge interface MAC address.

> [!NOTE]
> TODO: Find out why connectivity seems to be lost when the bridge interface receives an address before the physical interface.
> If connectivity is lost, release the addresses from both the bridge and the physical interface (in that order) with `sudo dhclient -v -r <iface>` and then run `sudo dhclient -v <iface>` to assign the bridge interface an address.

### Add the VMs to the Bridge

The configuration of the qemu network options in the job file will create a new tap interface and add it to the bridge and the VM. I advise you for your own sanity to never touch the network options, they will only cause you pain.

For others looking, this configuration is specific to *QEMU only*.

```bash
qemu-system-x86_64 ... -netdev bridge,id=hn0 -device virtio-net-pci,netdev=hn0,id=nic1
```

This will assign the VM an address on the external network. The VM will be able to communicate with the host and other VMs in the network.

You must also add `allow br0` to `/etc/qemu/bridge.conf` to allow qemu to add the tap interfaces to the bridge. [Source](https://wiki.qemu.org/Features/HelperNetworking)

The VMs, once connected to the bridge, will be assigned an address via DHCP. You can assign a static IP address to the VMs by adding a DHCP static lease on the [UDM](https://docs.redbrick.dcu.ie/hardware/network/mordor/) for the VMs MAC address. You can get the address of a VM by checking the `nomad alloc logs` for that VM and searching for `ens3`.

```bash
nomad job status distro-vm | grep "Node ID" -A 1 | tail -n 1 | cut -d " " -f 1
# <alloc-id>
nomad alloc logs <alloc-id> | grep -E "ens3.*global" | cut -d "|" -f 4 | xargs
# cloud init... ens3: <ip-address> global
```

## Configuring the VMs

The VMs are configured with cloud-init. Their [docs](https://cloudinit.readthedocs.io/en/latest/) are pretty good, so I won't repeat them here. The files can be served by any HTTP server, and the address is placed into the job file in the QEMU options.

```hcl title="Nomad"
...
        args = [
          ...

          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:22", # make sure this MAC address is unique!!

          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://vm-resources.service.consul:8000/res/",
        ]
...
```


Here in the args block:

- we define that the VM will have a network device using the `virtio` driver, we pass it an `id` and a random ***unique*** MAC address
- we tell it to use `smbios` type 1 and to grab its `cloud-init` configs from `http://vm-resources.service.consul:8000/res/`

> [!NOTE]
> If you're running multiple VMs on the same network make sure to set different MAC addresses for each VM, otherwise you'll have a bad time.

## Creating a New VM

To create a new VM, you'll need to create a new job file and a cloud-init configuration file. Copy any of the existing job files and modify them to suit your needs. The cloud-init configuration files can be copied and changed based on the user also. **Remember to ensure the MAC addresses are unique!**


