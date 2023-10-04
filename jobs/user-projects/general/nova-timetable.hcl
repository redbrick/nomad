job "nova-timetable" {
  datacenters = ["aperture"]

  type = "service"

  group "nova-timetable" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      port = "http"
      name = "nova-timetable"
      check {
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nova-timetable.rule=Host(`timetable.redbrick.dcu.ie`)",
        "traefik.http.routers.nova-timetable.tls=true",
      ]
    }

    task "python-application" {
      driver = "docker"
      config {
        image = "novanai/timetable-sync"
        ports = ["http"]
      }
    }
  }
}
