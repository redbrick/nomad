job "searxng" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "search.redbrick.dcu.ie"
  }

  group "web" {
    network {
      mode = "bridge"
      port "http" {
        to = 8080
      }

      port "redis" {
        to = 6379
      }
    }

    service {
      name = "searxng"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.searxng.entrypoints=web,websecure",
        "traefik.http.routers.searxng.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.searxng.tls=true",
        "traefik.http.routers.searxng.tls.certresolver=rb",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image = "docker.io/searxng/searxng:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/searxng:/etc/searxng",
          "/storage/nomad/${NOMAD_JOB_NAME}/cache:/var/cache/searxng",
        ]
      }

      resources {
        cpu    = 1000
        memory = 500
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
SEARXNG_BASE_URL=https://{{ env "NOMAD_META_domain" }}
SEARXNG_VALKEY_URL=valkey://{{ env "NOMAD_ADDR_redis" }}/0
SEARXNG_PUBLIC_INSTANCE=true
FORCE_OWNERSHIP=true

EOH
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image   = "docker.io/valkey/valkey:9-alpine"
        ports   = ["redis"]
        command = "valkey-server"
        args    = ["--save 30", "1", "--loglevel warning"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/data",
        ]
      }
    }
  }
}
