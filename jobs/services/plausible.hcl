job "plausible" {
  datacenters = ["aperture"]
  type = "service"

  group "web" {
    network {
      port "http" {
        to = 8000
      }
      port "db" {
        static = 8123
      }
    }

    task "plausible" {
      service {
        name = "plausible"
        port = "http"

        check {
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.plausible.rule=Host(`plausible.redbrick.dcu.ie`)",
          "traefik.http.routers.plausible.entrypoints=websecure",
          "traefik.http.routers.plausible.tls.certresolver=lets-encrypt"
        ]
      }

      driver = "docker"

      config {
        image = "ghcr.io/plausible/community-edition:v2.1.1"
        ports = ["http"]

        command = "/bin/sh"
        args = ["-c", "sleep 10 && /entrypoint.sh db migrate && /entrypoint.sh run"]
      }

      template {
        data = <<EOH
BASE_URL=https://plausible.redbrick.dcu.ie
SECRET_KEY_BASE={{ key "plausible/secret" }}
TOTP_VAULT_KEY={{ key "plausible/totp/key" }}

# Maxmind/GeoIP settings (for regions/cities)
MAXMIND_LICENSE_KEY={{ key "plausible/maxmind/license" }}
MAXMIND_EDITION=GeoLite2-City

# Google search console integration
GOOGLE_CLIENT_ID={{ key "plausible/google/client_id" }}
GOOGLE_CLIENT_SECRET={{ key "plausible/google/client_secret" }}

# Database settings
DATABASE_URL=postgres://{{ key "plausible/db/user" }}:{{ key "plausible/db/password" }}@postgres.service.consul:5432/{{ key "plausible/db/name" }}
CLICKHOUSE_DATABASE_URL=http://{{ env "NOMAD_ADDR_db" }}/plausible_events_db

# Email settings
MAILER_NAME="Redbrick Plausible"
MAILER_EMAIL={{ key "plausible/smtp/from" }}
MAILER_ADAPTER=Bamboo.SMTPAdapter
SMTP_HOST_ADDR={{ key "plausible/smtp/host" }}
SMTP_HOST_PORT={{ key "plausible/smtp/port" }}
SMTP_USER_NAME={{ key "plausible/smtp/user" }}
SMTP_USER_PWD={{ key "plausible/smtp/password" }}

DISABLE_REGISTRATION=invite_only
EOH
        destination = "local/file.env"
        env = true
      }

      resources {
        memory = 1000
      }
    }

    task "clickhouse" {
      constraint {
        attribute = "${attr.unique.hostname}"
        value     = "chell"
      }

      service {
        name = "plausible-clickhouse"
        port = "db"
      }

      driver = "docker"

      config {
        image = "clickhouse/clickhouse-server:24.3.3.102-alpine"
        ports = ["db"]
        volumes = [
          "/opt/plausible/clickhouse:/var/lib/clickhouse",
          "local/clickhouse.xml:/etc/clickhouse-server/config.d/logging.xml:ro",
          "local/clickhouse-user-config.xml:/etc/clickhouse-server/users.d/logging.xml:ro"
        ]
      }

      template {
        data = <<EOH
<clickhouse>
    <logger>
        <level>warning</level>
        <console>true</console>
    </logger>

    <!-- Stop all the unnecessary logging -->
    <query_thread_log remove="remove"/>
    <query_log remove="remove"/>
    <text_log remove="remove"/>
    <trace_log remove="remove"/>
    <metric_log remove="remove"/>
    <asynchronous_metric_log remove="remove"/>
    <session_log remove="remove"/>
    <part_log remove="remove"/>
</clickhouse>
EOH
        destination = "local/clickhouse.xml"
      }

      template {
        data = <<EOH
<clickhouse>
    <profiles>
        <default>
            <log_queries>0</log_queries>
            <log_query_threads>0</log_query_threads>
        </default>
    </profiles>
</clickhouse>
EOH
        destination = "local/clickhouse-user-config.xml"
      }

      resources {
        memory = 800
      }
    }
  }
}
