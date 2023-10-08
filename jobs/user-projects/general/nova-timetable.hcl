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

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nova-timetable.rule=Host(`timetable.redbrick.dcu.ie`)",
        "traefik.http.routers.nova-timetable.entrypoints=web,websecure",
        "traefik.http.routers.nova-timetable.tls.certresolver=lets-encrypt",
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
