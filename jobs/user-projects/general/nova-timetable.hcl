job "nova-timetable" {
  datacenters = ["aperture"]

  type = "service"

  group "nova-timetable" {
    count = 1

    network {
      port "http" {
        to = 80
      }

      port "db" {
        to = 6379
      }
    }

    service {
      name = "nova-timetable"
      port = "http"

      check {
        type = "http"
        path = "/healthcheck"
        interval = "10s"
        timeout = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nova-timetable.rule=Host(`timetable.redbrick.dcu.ie`)",
        "traefik.http.routers.nova-timetable.entrypoints=web,websecure",
        "traefik.http.routers.nova-timetable.tls.certresolver=lets-encrypt",
      ]
    }

    task "python-application" {
      driver = "docker"

      env {
        REDIS_ADDRESS = "${NOMAD_ADDR_db}"
      }

      config {
        image = "novanai/timetable-sync"
        ports = ["http"]
      }
    }

    task "redis-db" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["db"]
      }
    }
  }
}