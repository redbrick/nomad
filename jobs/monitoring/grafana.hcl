job "grafana" {
  datacenters = ["aperture"]

  type = "service"

  group "monitoring" {
    network {
      port "http" {
        to = 3000
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "grafana"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.entrypoints=web,websecure",
        "traefik.http.routers.grafana.rule=Host(`grafana.redbrick.dcu.ie`)",
        "traefik.http.routers.grafana.tls=true",
        "traefik.http.routers.grafana.tls.certresolver=lets-encrypt",
      ]
    }

    task "grafana" {
      driver = "docker"
      user   = "1001:1001"

      env {
        GF_AUTH_BASIC_ENABLED = "true"
        GF_INSTALL_PLUGINS    = "grafana-piechart-panel"
        GF_SERVER_ROOT_URL    = "https://grafana.redbrick.dcu.ie"
      }

      config {
        image = "grafana/grafana"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/grafana",
          "local/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml"
        ]
      }

      template {
        data        = <<EOH
GF_DATABASE_TYPE=postgres
GF_DATABASE_HOST={{ env "NOMAD_ADDR_db" }}
GF_DATABASE_NAME={{ key "grafana/db/name" }}
GF_DATABASE_USER={{ key "grafana/db/user" }}
GF_DATABASE_PASSWORD={{ key "grafana/db/password" }}
GF_FEATURE_TOGGLES_ENABLE=publicDashboards
GF_LOG_LEVEL=debug
EOH
        destination = "local/.env"
        env         = true
      }
      template {
        data        = <<EOH
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    {{- range service "prometheus" }}
    url: http://prometheus.service.consul:{{ .Port }}{{ end }}
    isDefault: true
    editable: false
EOH
        destination = "local/datasources.yml"
      }
    }
    task "db" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data",
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "grafana/db/password" }}
POSTGRES_USER={{ key "grafana/db/user" }}
POSTGRES_NAME={{ key "grafana/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}


