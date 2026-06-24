job "keepalived" {
  datacenters = ["aperture"]
  type        = "system"

  group "vip-glados" {
    constraint {
      attribute = "${meta.ingress_vip_node}"
      value     = "1"
    }

    network {
      mode = "host"
    }

    task "keepalived" {
      driver = "docker"

      config {
        image        = "osixia/keepalived:2.3.4"
        network_mode = "host"
        privileged   = true

        volumes = [
          "local/keepalived.conf:/etc/keepalived/keepalived.conf:ro",
        ]

        args = [
          "--",
          "--dont-fork",
          "--log-console",
          "--log-detail",
          "--dump-conf",
        ]
      }

      template {
        destination = "local/keepalived.conf"
        change_mode = "restart"

        data = <<EOF
global_defs {
  router_id glados
  enable_script_security
}

vrrp_instance VI_TRAEFIK_PUBLIC {
  state BACKUP
  interface br0
  virtual_router_id 50
  priority 150
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass {{ key "keepalived/auth/pass" }}
  }

  unicast_src_ip 136.206.16.4

  unicast_peer {
    136.206.16.5
    136.206.16.6
  }

  virtual_ipaddress {
    136.206.16.50/24 dev br0
  }
}
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  group "vip-wheatley" {
    constraint {
      attribute = "${meta.ingress_vip_node}"
      value     = "2"
    }

    network {
      mode = "host"
    }

    task "keepalived" {
      driver = "docker"

      config {
        image        = "osixia/keepalived:2.3.4"
        network_mode = "host"
        privileged   = true

        volumes = [
          "local/keepalived.conf:/etc/keepalived/keepalived.conf:ro",
        ]

        args = [
          "--",
          "--dont-fork",
          "--log-console",
          "--log-detail",
          "--dump-conf",
        ]
      }

      template {
        destination = "local/keepalived.conf"
        change_mode = "restart"
        data        = <<EOF
global_defs {
  router_id wheatley
  enable_script_security
}

vrrp_instance VI_TRAEFIK_PUBLIC {
  state BACKUP
  interface vlan16
  virtual_router_id 50
  priority 100
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass {{ key "keepalived/auth/pass" }}
  }

  unicast_src_ip 136.206.16.5

  unicast_peer {
    136.206.16.4
    136.206.16.6
  }

  virtual_ipaddress {
    136.206.16.50/24 dev vlan16
  }
}
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  group "vip-chell" {
    constraint {
      attribute = "${meta.ingress_vip_node}"
      value     = "3"
    }

    network {
      mode = "host"
    }

    task "keepalived" {
      driver = "docker"

      config {
        image        = "osixia/keepalived:2.3.4"
        network_mode = "host"
        privileged   = true

        volumes = [
          "local/keepalived.conf:/etc/keepalived/keepalived.conf:ro",
        ]

        args = [
          "--",
          "--dont-fork",
          "--log-console",
          "--log-detail",
          "--dump-conf",
        ]
      }

      template {
        destination = "local/keepalived.conf"
        change_mode = "restart"
        data        = <<EOF
global_defs {
  router_id chell
  enable_script_security
}

vrrp_instance VI_TRAEFIK_PUBLIC {
  state BACKUP
  interface vlan16
  virtual_router_id 50
  priority 50
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass {{ key "keepalived/auth/pass" }}
  }

  unicast_src_ip 136.206.16.6

  unicast_peer {
    136.206.16.4
    136.206.16.5
  }

  virtual_ipaddress {
    136.206.16.50/24 dev vlan16
  }
}
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
