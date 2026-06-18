job "pitwall" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "pitwall.solarracing.ie"
  }

  group "pitwall" {
    count          = 1
    shutdown_delay = "5s"

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "pitwall"
      port = "http"

      check {
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.pitwall.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.pitwall.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-dev.tls=true",
      ]
    }

    task "pitwall-dashboard" {
      driver = "docker"

      config {
        image      = "ghcr.io/dcu-solar-racing/solarcar-ecs-pit-dashboard:latest"
        ports      = ["http"]
        force_pull = true

        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
      }

      template {
        destination = "secrets/secret.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
DOCKER_USER={{ key "dcusr/ghcr/username" }}
DOCKER_PASS={{ key "dcusr/ghcr/password" }}
EOH
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}

