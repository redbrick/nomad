job "cawnj-test" {
  datacenters = ["aperture"]

  type = "service"

  group "cawnj-test" {
    count = 1

    network {
      port "http" {
        to = "80"
      }

      port "https" {
        to = "443"
      }
    }

    service {
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.cawnj-test.rule=Host(`cawnj-test.redbrick.dcu.ie`)",
        "traefik.http.routers.cawnj-test.entrypoints=web,websecure",
        "traefik.http.routers.cawnj-test.tls.certresolver=lets-encrypt"
      ]
    }

    task "webserver" {
      driver = "docker"

      config {
        image = "nginx"
        ports = ["http", "https"]
      }
    }
  }
}
