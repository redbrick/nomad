job "shlink" {
  datacenters = ["aperture"]

  type = "service"

  group "web" {
    network {
      port "api" {
        to = 8080
      }
      port "web" {
        to = 8080
      }
    }

    service {
      name = "shlink"
      port = "api"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.shlink-api.entrypoints=web,websecure",
        "traefik.http.routers.shlink-api.rule=Host(`s.rb.dcu.ie`)",
        "traefik.http.routers.shlink-api.tls=true",
        "traefik.http.routers.shlink-api.tls.certresolver=lets-encrypt",
      ]
    }

    task "shlink" {
      driver = "docker"

      config {
        image = "shlinkio/shlink"
        ports = ["api"]
      }

      template {
        data = <<EOH
DEFAULT_DOMAIN=s.rb.dcu.ie
IS_HTTPS_ENABLED=true
DB_DRIVER=postgres
DB_USER={{ key "shlink/db/user" }}
DB_PASSWORD={{ key "shlink/db/password" }}
DB_NAME={{ key "shlink/db/name" }}
DB_HOST=postgres.service.consul
GEOLITE_LICENSE_KEY={{ key "shlink/geolite/key" }}
EOH
        destination = "local/file.env"
        env         = true
      }
      resources {
        memory = 1000
      }
    }

#    task "shlink-web-client" {
#      driver = "docker"
#
#      config {
#        image = "shlinkio/shlink-web-client"
#        ports = ["web"]
#      }
#
#      template {
#        data = <<EOH
#SHLINK_SERVER_URL=https://s.rb.dcu.ie
#SHLINK_API_KEY={{ key "shlink/api/key" }}
#EOH
#        destination = "local/file.env"
#        env         = true
#      }
#
#
#
#      service {
#        name = "shlink"
#        port = "api"
#
#        tags = [
#          "traefik.enable=true",
#          "traefik.http.routers.shlink-web.entrypoints=web,websecure",
#          "traefik.http.routers.shlink-web.rule=Host(`shlink.rb.dcu.ie`)",
#          "traefik.http.routers.shlink-web.tls=true",
#          "traefik.http.routers.shlink-web.tls.certresolver=lets-encrypt",
#        ]
#      }
#      resources {
#        memory = 500
#      }
#    }
  }
}

