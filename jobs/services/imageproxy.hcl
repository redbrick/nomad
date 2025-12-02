job "imageproxy" {
  datacenters = ["aperture"]

  type = "service"

  group "web" {
    network {
      port "http" {
        to = 8080
      }
      port "redis" {
        to = 6379
      }
    }

    service {
      name = "imageproxy"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.imageproxy-api.rule=Host(`img.redbrick.dcu.ie`)",
        "traefik.http.routers.imageproxy-api.tls=true",
        "traefik.http.routers.imageproxy-api.tls.certresolver=rb",
      ]
    }

    task "imageproxy" {
      driver = "docker"

      config {
        image = "ghcr.io/willnorris/imageproxy:latest"
        ports = ["http"]
      }
      template {
        data        = <<EOH
IMAGEPROXY_BASEURL=https://img.redbrick.dcu.ie
IMAGEPROXY_CACHE=redis://{{ env "NOMAD_ADDR_redis" }}
IMAGEPROXY_REFERRERS=redbrick.dcu.ie,rb.dcu.ie,redbrick.ie,*.redbrick.dcu.ie,*.rb.dcu.ie,*.redbrick.ie,localhost
# IMAGEPROXY_ALLOWHOSTS
EOH
        destination = "local/.env"
        env         = true
      }
      resources {
        cpu    = 500
        memory = 5000
      }
    }
    task "redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        ports = ["redis"]
      }
    }
  }
}

