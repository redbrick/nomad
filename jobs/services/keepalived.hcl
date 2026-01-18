job "keepalived" {
  datacenters = ["aperture"]
  # node_pool   = "ingress"
  type = "service"

  group "vrrp" {
    count = 2
    network {
      mode = "host"
    }

    task "keepalived" {
      driver = "docker"

      config {
        image        = "shawly/keepalived:2"
        network_mode = "host"
        privileged   = true

        volumes = [
          "local/keepalived.conf:/etc/keepalived/keepalived.conf:ro"
        ]
      }
      env {
        KEEPALIVED_CUSTOM_CONFIG = true
      }

      template {
        data        = <<EOF
global_defs {
    router_id {{ env "node.unique.name" }}
}

vrrp_script chk_traefik {
    script "/usr/bin/nc -zv 127.0.0.1 8080"
    interval 2
    weight 20
}

vrrp_instance VI_1 {
    state BACKUP
    interface br0
    virtual_router_id 51
    priority 100
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass redbrick_ha_2026
    }

    unicast_src_ip {{ env "attr.unique.network.ip-address" }}
    unicast_peer {
        {{- range $index, $node := nodes -}}
        {{- if ne $node.ID (env "node.unique.id") }}
        {{ $node.Address }}
        {{- end -}}
        {{- end }}
    }

    virtual_ipaddress {
        136.206.16.69/24
    }

    track_script {
        chk_traefik
    }
}
EOF
        destination = "local/keepalived.conf"
        change_mode = "restart"
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
