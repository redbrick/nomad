job "node-exporter" {
  datacenters = ["aperture"]
  type        = "system"

  group "node-exporter" {
    network {
      mode = "bridge"

      port "metrics" {
        to = 9100
      }
    }

    service {
      name = "node-exporter"
      port = "metrics"
    }

    task "node-exporter" {
      driver = "docker"

      config {
        image = "prom/node-exporter:latest"
        ports = ["metrics"]

        pid_mode = "host"

        volumes = [
          "/:/host:ro,rslave",
        ]

        args = [
          "--path.rootfs=/host",
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
