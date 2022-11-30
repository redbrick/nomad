datacenter = {{ nomad_datacenter_name }}
data_dir = "/opt/nomad"

bind_addr = "0.0.0.0"

advertise {
  http = "{{ ansible_default_ipv4[address] }}"
  rpc  = "{{ ansible_default_ipv4[address] }}"
  serf = "{{ ansible_default_ipv4[address] }}"
}
