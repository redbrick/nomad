job "nginx" {
  datacenters = ["aperture"]

  type = "service"

  group "web" {
    count = 5
    
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
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      } 
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx.rule=Host(`aperture.redbrick.dcu.ie`)",   
        "traefik.http.routers.nginx.entrypoints=web,websecure",
        #"traefik.port=${NOMAD_PORT_http}"
      ]
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "nginx"
        ports = ["http", "https"]
        volumes = [
          "local/index.html:/usr/share/nginx/html/index.html",
        ]
      }

      artifact {
        source = "https://raw.githubusercontent.com/redbrick/nomad/master/nginx/index.html"
      }

      template {
        source = "local/index.html"
        destination = "local/index.html"
      }
    }
  }
}
