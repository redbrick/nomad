job "mps-site" {
  datacenters = ["aperture"]
  type        = "service"

  group "mps-django" {
    count = 1

    network {
      port "http" {
        to = 8000
      }
    }

    service {
      name = "mps-django"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.mps-django.rule=Host(`mps.rb.dcu.ie`) || Host(`dcumps.ie`) || Host(`www.dcumps.ie`) || Host(`dcumps.com`) || Host(`www.dcumps.com`)",
        "traefik.http.routers.mps-django.entrypoints=web,websecure",
        "traefik.http.routers.mps-django.tls.certresolver=lets-encrypt",
        "traefik.http.routers.mps-django.middlewares=mps-django-redirect-com",
        "traefik.http.middlewares.mps-django-redirect-com.redirectregex.regex=dcumps\\.com/(.*)",
        "traefik.http.middlewares.mps-django-redirect-com.redirectregex.replacement=dcumps.ie/$1",
      ]
    }

    task "django-web" {
      driver = "docker"

      config {
        image      = "ghcr.io/dcumps/dcumps-website-django:latest"
        ports      = ["http"]
        force_pull = true
        hostname   = "${NOMAD_TASK_NAME}"
        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
        volumes = [
          "local/hosts:/etc/hosts",
        ]
      }

      template {
        data        = <<EOH
DOCKER_USER={{ key "mps/site/ghcr/username" }}
DOCKER_PASS={{ key "mps/site/ghcr/password" }}
EOH
        destination = "local/.env"
        env         = true
      }

      template {
        data        = <<EOF
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
172.17.0.17	{{ env "NOMAD_TASK_NAME" }}
# use internal IP for thecollegeview.ie as external IP isn't routable
192.168.0.158 thecollegeview.ie
192.168.0.158 www.thecollegeview.ie
EOF
        destination = "local/hosts"
      }


      resources {
        cpu    = 300
        memory = 500
      }
    }
  }
}
