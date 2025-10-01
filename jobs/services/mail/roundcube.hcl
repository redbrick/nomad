job "roundcube" {
  datacenters = ["aperture"]

  type = "service"

  group "roundcube" {
    count = 1

    network {
      port "http" {
        to = 80
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "roundcube-web"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.roundcube.rule=Host(`webmail.rb.dcu.ie`)",
        "traefik.http.routers.roundcube.entrypoints=web,websecure",
        "traefik.http.routers.roundcube.tls.certresolver=lets-encrypt",
      ]
    }

    task "roundcube" {
      driver = "docker"

      config {
        image = "roundcube/roundcubemail:latest"
        ports = ["http"]
        hostname = "webmail.rb.dcu.ie"

        volumes = [
          "/storage/nomad/roundcube/www:/var/www/html",
        ]
      }
      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
ROUNDCUBEMAIL_DB_TYPE=pgsql
ROUNDCUBEMAIL_DB_HOST={{ env "NOMAD_IP_db" }}
ROUNDCUBEMAIL_DB_PORT={{ env "NOMAD_HOST_PORT_db" }}
ROUNDCUBEMAIL_DB_NAME={{ key "roundcube/db/name" }}
ROUNDCUBEMAIL_DB_USER={{ key "roundcube/db/user" }}
ROUNDCUBEMAIL_DB_PASSWORD={{ key "roundcube/db/password" }}
ROUNDCUBEMAIL_SKIN=elastic
ROUNDCUBEMAIL_DEFAULT_HOST={{ key "roundcube/imap/host" }}
ROUNDCUBEMAIL_DEFAULT_PORT={{ key "roundcube/imap/port" }}
ROUNDCUBEMAIL_SMTP_SERVER={{ key "roundcube/smtp/host" }}
ROUNDCUBEMAIL_SMTP_PORT={{ key "roundcube/smtp/port" }}
EOH
      }
    }
    task "roundcube-db" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/roundcube/db:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "roundcube/db/password" }}
POSTGRES_USER={{ key "roundcube/db/user" }}
POSTGRES_NAME={{ key "roundcube/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}
