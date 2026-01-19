job "nova-timetable" {
  datacenters = ["aperture"]
  type        = "service"

  group "nova-timetable" {
    count = 1

    network {
      port "valkey" {
        to = 6379
      }

      port "db" {
        to = 5432
      }

      port "frontend" {
        to = 3000
      }

      port "backend" {
        to = 2000
      }
    }

    task "frontend" {
      driver = "docker"

      env {
        PORT = "${NOMAD_PORT_frontend}"
      }

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
          "traefik.http.routers.nova-timetable-frontend.tls.certresolver=rb",
        ]
      }
    }

    task "backend" {
      driver = "docker"

      env {
        BACKEND_PORT = "${NOMAD_PORT_backend}"
        VALKEY_HOST  = "${NOMAD_IP_valkey}"
        VALKEY_PORT  = "${NOMAD_HOST_PORT_valkey}"
        CNS_ADDRESS  = "https://clubsandsocs.jakefarrell.ie"
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
          "traefik.http.routers.nova-timetable-backend.tls.certresolver=rb",
        ]
      }
      resources {
        memory = 800
      }
    }

    task "valkey" {
      driver = "docker"

      config {
        image = "valkey/valkey:9"
        ports = ["valkey"]
      }
    }

    task "timetable-db" {
      driver = "docker"

      config {
        image = "postgres:17.0-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/nova-timetable/db:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_USER={{ key "user-projects/nova/db/user" }}
POSTGRES_PASSWORD={{ key "user-projects/nova/db/password" }}
POSTGRES_DB={{ key "user-projects/nova/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }

    #     task "timetable-bot" {
    #       driver = "docker"

    #       config {
    #         image = "ghcr.io/novanai/timetable-sync-bot:latest"
    #       }

    #       template {
    #         data        = <<EOH
    # BOT_TOKEN={{ key "user-projects/nova/bot/token" }}
    # VALKEY_HOST={{ env "NOMAD_IP_valkey" }}
    # VALKEY_PORT={{ env "NOMAD_HOST_PORT_valkey" }}
    # POSTGRES_USER={{ key "user-projects/nova/db/user" }}
    # POSTGRES_PASSWORD={{ key "user-projects/nova/db/password" }}
    # POSTGRES_DB={{ key "user-projects/nova/db/name" }}
    # POSTGRES_HOST={{ env "NOMAD_IP_db" }}
    # POSTGRES_PORT={{ env "NOMAD_HOST_PORT_db" }}
    # CNS_ADDRESS="https://clubsandsocs.jakefarrell.ie"
    # EOH
    #         destination = "local/.env"
    #         env         = true
    #       }
    #     }
  }
}
