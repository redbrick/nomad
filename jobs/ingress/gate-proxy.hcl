job "gate-proxy" {
  datacenters = ["aperture"]
  node_pool = "ingress"
  type = "service"

  group "gate-proxy" {
    count = 1

    network {
      port "mc" {
        static = 4501
      }
    }

    service {
      port = "mc"

      check {
        type = "tcp"
        interval = "10s"
        timeout = "2s"
      }
    }

    task "gate-proxy" {
      driver = "docker"

      config {
        image = "ghcr.io/minekube/gate"
        ports = ["mc"]

        volumes = [
          "local/file.conf:/config.yaml"
        ]
      }

      template {
        data = <<EOH
# This is a simplified config where the rest of the
# settings are omitted and will be set by default.
# See config.yml for the full configuration options.
config:
  bind: 0.0.0.0:4501

  forwarding:
    mode: legacy

  lite:
    enabled: true
    routes:
      - host: mc.rb.dcu.ie
        backend: vanilla-mc.service.consul:25567
      - host: olim909.rb.dcu.ie
        backend: olim909-mc.service.consul:25568
      - host: games.rb.dcu.ie
        backend: games-mc.service.consul:25569
EOH
        destination = "local/file.conf"
      }
    }
  }
}
