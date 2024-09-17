job "nova-timetable" {
  datacenters = ["aperture"]
  type        = "service"

  group "nova-timetable" {
    count = 1

    network {
      port "db" {
        to = 6379
      }

      port "frontend" {
        to = 3000
      }

      port "backend" {
        to = 4000
      }
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "ghcr.io/novanai/timetable-sync-frontend:latest"
        ports = ["frontend"]
      }

      service {
        name = "nova-timetable-frontend"
        port = "frontend"

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.port=${NOMAD_PORT_frontend}",
          "traefik.http.routers.nova-timetable-frontend.rule=Host(`timetable.redbrick.dcu.ie`)",
          "traefik.http.routers.nova-timetable-frontend.entrypoints=web,websecure",
          "traefik.http.routers.nova-timetable-frontend.tls.certresolver=lets-encrypt",
        ]
      }
    }

    task "backend" {
      driver = "docker"

      env {
        REDIS_ADDRESS = "${NOMAD_ADDR_db}"
      }

      config {
        image = "ghcr.io/novanai/timetable-sync-backend:latest"
        ports = ["backend"]
      }

      service {
        name = "nova-timetable-backend"
        port = "backend"

        check {
          type     = "http"
          path     = "/api/healthcheck"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.port=${NOMAD_PORT_backend}",
          "traefik.http.routers.nova-timetable-backend.rule=Host(`timetable.redbrick.dcu.ie`) && PathPrefix(`/api`)",
          "traefik.http.routers.nova-timetable-backend.entrypoints=web,websecure",
          "traefik.http.routers.nova-timetable-backend.tls.certresolver=lets-encrypt",
        ]
      }
    }

    task "redis-db" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["db"]
      }
    }


    task "timetablebot" {
      driver = "docker"

      config {
        image = "ghcr.io/novanai/timetable-sync-bot:latest"
      }

      template {
        data        = <<EOH
BOT_TOKEN={{ key "user-projects/nova/timetablebot/token" }}
REDIS_ADDRESS={{ env "NOMAD_ADDR_db" }}
EOH
        destination = "local/.env"
        env         = true
      }
    }
  }
}
