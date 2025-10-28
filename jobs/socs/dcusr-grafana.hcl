job "dcusr-grafana" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "dashboard.solarracing.ie"
  }

  group "grafana" {
    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "grafana"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.grafana.entrypoints=web,websecure",
        "traefik.http.routers.grafana.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.grafana.tls=true",
        "traefik.http.routers.grafana.tls.certresolver=lets-encrypt",
      ]
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/data:/var/lib/grafana",
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/plugins:/var/lib/grafana/plugins"
        ]
      }

      template {
        data        = <<EOH
GF_PLUGINS_PREINSTALL=grafana-clock-panel
GF_USERS_ALLOW_SIGN_UP=false
EOH
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 1000
      }
    }
  }
}

