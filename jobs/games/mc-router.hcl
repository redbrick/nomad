job "mc-router" {
  datacenters = ["aperture"]

  type = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    value = "bastion-vm"
  }

  group "mc-router" {
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

    task "webserver" {
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

  lite:
    enabled: true

    routes:
      - host: fugitives.rb.dcu.ie
        backend: fugitives-mc.service.consul:25566
      - host: mc.rb.dcu.ie
        backend: vanilla-mc.service.consul:25567
      - host: shemek.rb.dcu.ie
        backend: shemek-mc.service.consul:25568
      - host: games.rb.dcu.ie
        backend: games-mc.service.consul:25569
EOH
        destination = "local/file.conf"
      }
    }
  }
}