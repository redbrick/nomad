job "hedgedoc" {
  datacenters = ["aperture"]

  type = "service"

  group "web" {
    network {
      # mode = "bridge"
      port "http" {
        to = 3000
      }

      port "db" {
        to = 5432
      }
    }

    service {
      name = "hedgedoc"
      port = "http"

      check {
        type     = "http"
        path     = "/_health"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.frontend.headers.STSSeconds=63072000",
        "traefik.frontend.headers.browserXSSFilter=true",
        "traefik.frontend.headers.contentTypeNosniff=true",
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.md.entrypoints=web,websecure",
        "traefik.http.routers.md.rule=Host(`md.redbrick.dcu.ie`) || Host(`md.rb.dcu.ie`)",
        "traefik.http.routers.md.tls.certresolver=lets-encrypt",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image = "quay.io/hedgedoc/hedgedoc:1.10.2"
        ports = ["http"]
        volumes = [
          "/storage/nomad/hedgedoc/banner:/hedgedoc/public/banner",
        ]
      }

      template {
        data        = <<EOH
CMD_DB_URL                  = "postgres://{{ key "hedgedoc/db/user" }}:{{ key "hedgedoc/db/password" }}@{{ env "NOMAD_ADDR_db" }}/{{ key "hedgedoc/db/name" }}"
CMD_ALLOW_FREEURL           = "false"
CMD_FORBIDDEN_NOTE_IDS      = ['robots.txt', 'favicon.ico', 'api', 'build', 'css', 'docs', 'fonts', 'js', 'uploads', 'vendor', 'views', 'auth']
CMD_DOMAIN                  = "md.redbrick.dcu.ie"
CMD_ALLOW_ORIGIN            = ["redbrick.dcu.ie", "rb.dcu.ie"]
CMD_USE_CDN                 = "true"
CMD_PROTOCOL_USESSL         = "true"
CMD_URL_ADDPORT             = "false"
CMD_LOG_LEVEL               = "debug"
CMD_ENABLE_STATS_API        = "true"

# Accounts
CMD_ALLOW_EMAIL_REGISTER    = "false"
CMD_ALLOW_ANONYMOUS         = "false"
CMD_ALLOW_ANONYMOUS_EDITS   = "false"
CMD_EMAIL                   = "false"
CMD_LDAP_URL                = "{{ key "hedgedoc/ldap/url" }}"
CMD_LDAP_SEARCHBASE         = "{{ key "hedgedoc/ldap/basedn" }}"
CMD_LDAP_BINDDN             = "{{ key "hedgedoc/ldap/binddn" }}"
CMD_LDAP_BINDCREDENTIALS    = "{{ key "hedgedoc/ldap/password" }}"
CMD_LDAP_SEARCHFILTER       = "{{`(uid={{username}})`}}"
CMD_LDAP_PROVIDERNAME       = "Redbrick"
CMD_LDAP_USERIDFIELD        = "uidNumber"
CMD_LDAP_USERNAMEFIELD      = "uid"
CMD_SESSION_SECRET          = "{{ key "hedgedoc/session/secret" }}"
CMD_DEFAULT_PERMISSION      = "limited"

# Security/Privacy
CMD_HSTS_PRELOAD            = "true"
CMD_CSP_ENABLE              = "true"
CMD_HSTS_INCLUDE_SUBDOMAINS = "true"
CMD_CSP_ADD_DISQUS          = "false"
CMD_CSP_ADD_GOOGLE_ANALYTICS= "false"
CMD_CSP_ALLOW_PDF_EMBED     = "true"
CMD_ALLOW_GRAVATAR          = "true"

# Uploads
CMD_IMAGE_UPLOAD_TYPE       = "imgur"
CMD_IMGUR_CLIENTID          = "{{ key "hedgedoc/imgur/clientid" }}"
CMD_IMGUR_CLIENTSECRET      = "{{ key "hedgedoc/imgur/clientsecret" }}"
EOH
        destination = "local/.env"
        env         = true
      }
    }

    task "hedgedoc-db" {
      driver = "docker"

      config {
        image = "postgres:13.4-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/hedgedoc:/var/lib/postgresql/data",
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "hedgedoc/db/password" }}
POSTGRES_USER={{ key "hedgedoc/db/user" }}
POSTGRES_NAME={{ key "hedgedoc/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}
