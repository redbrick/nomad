job "wetty" {
  datacenters = ["aperture"]

  type = "service"

  group "wetty" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "wetty"
      port = "http"

      check {
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.wetty.rule=Host(`wetty.rb.dcu.ie`)",
        "traefik.http.routers.wetty.entrypoints=web,websecure",
        "traefik.http.routers.wetty.tls.certresolver=lets-encrypt",
      ]
    }

    task "wetty" {
      driver = "docker"

      config {
        image = "wettyoss/wetty"
        ports = ["http"]
      }
      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
SSHHOST={{ key "wetty/ssh/host" }}
SSHPORT=22
EOH
      }
    }
  }
}
