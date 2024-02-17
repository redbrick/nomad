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
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.frontend.headers.STSSeconds=63072000",
        "traefik.frontend.headers.browserXSSFilter=true",
        "traefik.frontend.headers.contentTypeNosniff=true",
        "traefik.frontend.headers.customResponseHeaders=alt-svc:h2=l3sb47bzhpbelafss42pspxzqo3tipuk6bg7nnbacxdfbz7ao6semtyd.onion:443; ma=2592000",
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.md.rule=Host(`md.redbrick.dcu.ie`,`md.rb.dcu.ie`)",
        "traefik.http.routers.md.tls=true",
        "traefik.http.routers.md.tls.certresolver=lets-encrypt",
      ]
    }

    task "app" {
      driver = "docker"

      constraint {
        attribute = "${attr.unique.hostname}"
        value = "chell"
      }

      config {
        image = "quay.io/hedgedoc/hedgedoc:1.6.0"
        ports = ["http"]
      }

      template {
        data        = <<EOH
CMD_IMAGE_UPLOAD_TYPE    = "imgur"
CMD_IMGUR_CLIENTID       = "{{ key "hedgedoc/imgur/clientid" }}"
CMD_IMGUR_CLIENTSECRET   = "{{ key "hedgedoc/imgur/clientsecret" }}"
CMD_DB_URL               = "postgres://{{ key "hedgedoc/db/user" }}:{{ key "hedgedoc/db/password" }}@{{ env "NOMAD_ADDR_db" }}/{{ key "hedgedoc/db/name" }}"
CMD_ALLOW_FREEURL        = "false"
CMD_DEFAULT_PERMISSION   = "private"
CMD_DOMAIN               = "md.redbrick.dcu.ie"
CMD_ALLOW_ORIGIN         = ["md.redbrick.dcu.ie", "md.rb.dcu.ie"]
CMD_HSTS_PRELOAD         = "true"
CMD_USE_CDN              = "true"
CMD_PROTOCOL_USESSL      = "true"
CMD_URL_ADDPORT          = "false"
CMD_ALLOW_EMAIL_REGISTER = "false"
CMD_ALLOW_ANONYMOUS      = "false"
CMD_EMAIL                = "false"
CMD_LDAP_URL             = "{{ key "hedgedoc/ldap/url" }}"
CMD_LDAP_SEARCHBASE      = "ou=accounts,o=redbrick"
CMD_LDAP_SEARCHFILTER    = "{{`(uid={{username}})`}}"
CMD_LDAP_PROVIDERNAME    = "Redbrick"
CMD_LDAP_USERIDFIELD     = "uidNumber"
CMD_LDAP_USERNAMEFIELD   = "uid"
CMD_ALLOW_GRAVATAR       = "true"
CMD_SESSION_SECRET       = "{{ key "hedgedoc/session/secret" }}"
CMD_LOG_LEVEL           = "debug"
EOH
        destination = "local/.env"
        env         = true
      }
    }

    task "hedgedoc-db" {
      driver = "docker"

      constraint {
        attribute = "${attr.unique.hostname}"
        value = "chell"
      }

      config {
        image = "postgres:9.6-alpine"
        ports = ["db"]

        volumes = [
            "/opt/postgres/hedgedoc:/var/lib/postgresql/data"
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
