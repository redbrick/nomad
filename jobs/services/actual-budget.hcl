job "actual-budget" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "actual.rb.dcu.ie"
  }

  group "actual-budget-web" {
    network {
      port "http" {
        to = 5006
      }
    }

    service {
      name = "actual-budget"
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
        "traefik.http.routers.actual-budget.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.actual-budget.entrypoints=web,websecure",
        "traefik.http.routers.actual-budget.tls.certresolver=lets-encrypt",
      ]
    }

    task "actual-budget" {
      driver = "docker"

      config {
        image = "docker.io/actualbudget/actual-server:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/data",
        ]
      }

      template {
        data        = <<EOH

EOH
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 800
        memory = 1000
      }
    }

  }
}
