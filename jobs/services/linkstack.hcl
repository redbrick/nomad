job "linkstack" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "links.rb.dcu.ie"
  }

  group "linkstack" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "linkstack"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.linkstack.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.linkstack.entrypoints=web,websecure",
        "traefik.http.routers.linkstack.tls.certresolver=lets-encrypt",
        "traefik.http.routers.linkstack.middlewares=linkstack",
        "traefik.http.middlewares.linkstack.headers.customrequestheaders.X-Forwarded-Proto=https",
        "traefik.http.middlewares.linkstack.headers.customResponseHeaders.X-Robots-Tag=none",
        "traefik.http.middlewares.linkstack.headers.customResponseHeaders.Strict-Transport-Security=max-age=63072000",
        "traefik.http.middlewares.linkstack.headers.stsSeconds=31536000",
        "traefik.http.middlewares.linkstack.headers.accesscontrolalloworiginlist=*",
      ]
    }


    task "linkstack" {
      driver = "docker"

      config {
        image = "linkstackorg/linkstack:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/htdocs"
        ]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      template {
        data        = <<EOH
TZ=Europe/Dublin
SERVER_ADMIN=elected-admins@redbrick.dcu.ie
HTTP_SERVER_NAME={{ env "NOMAD_META_domain" }}
HTTPS_SERVER_NAME={{ env "NOMAD_META_domain" }}
LOG_LEVEL=info
PHP_MEMORY_LIMIT=512M
UPLOAD_MAX_FILESIZE=16M
EOH
        destination = "local/.env"
        env         = true
      }
    }
  }
}
