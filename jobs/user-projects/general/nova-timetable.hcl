job "nova-timetable" {
  datacenters = ["aperture"]
  type        = "service"

  group "nova-timetable" {
    count = 1

    network {
      port "redis" {
        to = 6379
      }

      port "db" {
        to = 5432
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
        REDIS_ADDRESS = "${NOMAD_ADDR_redis}"
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

    task "redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["redis"]
      }
    }

    task "timetable-db" {
      driver = "docker"

      config {
        image = "postgres:17.0-alpine"
        ports = ["db"]

        volumes = [
          "/opt/postgres/nova-timetable:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_USER={{ key "user-projects/nova/db/user" }}
POSTGRES_PASSWORD={{ key "user-projects/nova/db/password" }}
POSTGRES_DB={{ key "user-projects/nova/db/db" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }

    task "timetable-bot" {
      driver = "docker"

      config {
        image = "ghcr.io/novanai/timetable-sync-bot:latest"
      }

      template {
        data        = <<EOH
BOT_TOKEN={{ key "user-projects/nova/bot/token" }}
REDIS_ADDRESS={{ env "NOMAD_ADDR_redis" }}
POSTGRES_USER={{ key "user-projects/nova/db/user" }}
POSTGRES_PASSWORD={{ key "user-projects/nova/db/password" }}
POSTGRES_DB={{ key "user-projects/nova/db/db" }}
POSTGRES_HOST={{ env "NOMAD_IP_db" }}
POSTGRES_PORT={{ env "NOMAD_PORT_db" }}
EOH
        destination = "local/.env"
        env         = true
      }
    }
  }
}
