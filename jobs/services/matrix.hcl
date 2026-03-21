job "matrix" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "matrix.redbrick.dcu.ie"
    main   = "redbrick.dcu.ie"
  }

  group "synapse" {
    count = 1

    network {

      port "http" {
        to = 8008
      }

      port "federation" {
        to = 8448
      }
    }

    service {
      name = "matrix-synapse"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.synapse.rule=Host(`${NOMAD_META_domain}`) && (PathPrefix(`/_matrix`) || PathPrefix(`/_synapse`))",
        "traefik.http.routers.synapse.entrypoints=websecure",
        "traefik.http.routers.synapse.tls=true",
        "traefik.http.routers.synapse.tls.certresolver=rb",
        "traefik.http.routers.synapse.priority=200",
        "traefik.http.routers.synapse-client-wellknown.rule=Host(`${NOMAD_META_main}`) && Path(`/.well-known/matrix/client`)",
        "traefik.http.routers.synapse-client-wellknown.entrypoints=websecure",
        "traefik.http.routers.synapse-client-wellknown.tls=true",
        "traefik.http.routers.synapse-client-wellknown.priority=200",
        "traefik.http.routers.synapse-server-wellknown.rule=Host(`${NOMAD_META_main}`) && Path(`/.well-known/matrix/server`)",
        "traefik.http.routers.synapse-server-wellknown.entrypoints=websecure",
        "traefik.http.routers.synapse-server-wellknown.tls=true",
        "traefik.http.routers.synapse-server-wellknown.priority=200",
      ]

      check {
        type     = "http"
        path     = "/_matrix/client/versions"
        interval = "30s"
        timeout  = "5s"
      }
    }

    service {
      name = "matrix-federation"
      port = "federation"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.synapse-federation.rule=Host(`${NOMAD_META_main}`)",
        "traefik.http.routers.synapse-federation.entrypoints=matrix",
        "traefik.http.routers.synapse-federation.tls=true",
        "traefik.http.routers.synapse-federation.tls.certresolver=rb",
      ]
    }

    task "synapse" {
      driver = "docker"

      config {
        image = "matrixdotorg/synapse:latest"
        ports = ["http", "federation"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/data",
          "local/discord.yaml:/bridges/discord.yaml:ro",
          "local/homeserver.yaml:/data/homeserver.yaml:ro",
          "local/log.config:/data/log.config",
        ]
      }

      template {
        destination = "secrets/synapse.env"
        env         = true
        data        = <<EOH
SYNAPSE_CONFIG_PATH=/data/homeserver.yaml
SYNAPSE_DATA_DIR=/data
EOH
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      template {
        destination = "local/homeserver.yaml"
        change_mode = "restart"
        data        = <<EOH
server_name: "{{ env "NOMAD_META_main" }}"
pid_file: /data/homeserver.pid
web_client_location: https://{{ env "NOMAD_META_domain" }}/
public_baseurl: https://{{ env "NOMAD_META_domain" }}/

app_service_config_files:
  - /bridges/discord.yaml

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

  - port: 8448
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [federation]
        compress: false

# Database
database:
  name: psycopg2
  args:
    user: {{ key "matrix/db/user" }}
    password: {{ key "matrix/db/password" }}
    database: {{ key "matrix/db/name" }}
    host: {{ range service "matrix-postgres" }}{{ .Address }}{{ end }}
    port: {{ range service "matrix-postgres" }}{{ .Port }}{{ end }}
    cp_min: 5
    cp_max: 10

# LDAP Authentication
modules:
  - module: "ldap_auth_provider.LdapAuthProviderModule"
    config:
      enabled: true
      uri: "ldap://{{ range service "openldap-ldap" }}{{ .Address }}:{{ .Port }}{{ end }}"
      start_tls: false
      base: "{{ key "matrix/ldap/basedn" }}"
      bind_dn: "{{ key "matrix/ldap/binddn" }}"
      bind_password: "{{ key "matrix/ldap/password" }}"

      attributes:
        uid: "uid"
        mail: "mail"
        name: "uid"

      # filter: "{ keyOrDefault "matrix/ldap_filter" "(objectClass=posixAccount)" }}"

# Registration
enable_registration: false
enable_registration_without_verification: false
registration_shared_secret: "{{ key "matrix/registration_secret" }}"
# enable_set_displayname: false
auto_join_rooms:
- '#redbrick:redbrick.dcu.ie'
- '#lobby:redbrick.dcu.ie'
- '#video-games:redbrick.dcu.ie'
- '#memes:redbrick.dcu.ie'
- '#food:redbrick.dcu.ie'
- '#music:redbrick.dcu.ie'
- '#hardware:redbrick.dcu.ie'
- '#security:redbrick.dcu.ie'
- '#sports:redbrick.dcu.ie'
- '#common-room-chat:redbrick.dcu.ie'
- '#pet-pics:redbrick.dcu.ie'
- '#bots:redbrick.dcu.ie'
- '#webgroup:redbrick.dcu.ie'
- '#webgroup-github:redbrick.dcu.ie'
- '#bot-dev:redbrick.dcu.ie'
- '#text-to-voice:redbrick.dcu.ie'


# Security
macaroon_secret_key: "{{ key "matrix/macaroon_secret" }}"
form_secret: "{{ key "matrix/form_secret" }}"
signing_key_path: "/data/signing.key"

# Report stats
report_stats: false

# Media
media_store_path: /data/media_store
max_upload_size: 100M
max_image_pixels: 32M

url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
  - '100.64.0.0/10'
  - '169.254.0.0/16'
  - '::1/128'
  - 'fe80::/64'
  - 'fc00::/7'

# Federation
federation_domain_whitelist: null
suppress_key_server_warning: true
trusted_key_servers:
  - server_name: "matrix.org"

# Ratelimiting
rc_message:
  per_second: 0.2
  burst_count: 10

rc_registration:
  per_second: 0.17
  burst_count: 3

rc_login:
  address:
    per_second: 0.17
    burst_count: 3
  account:
    per_second: 0.17
    burst_count: 3
  failed_attempts:
    per_second: 0.17
    burst_count: 3

# Retention
retention:
  enabled: false

# Presence
presence:
  enabled: true

# Logging
log_config: "/data/log.config"
EOH

      }

      template {
        destination = "local/log.config"
        change_mode = "restart"
        data        = <<EOH
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
    stream: ext://sys.stdout

loggers:
  synapse.storage.SQL:
    level: WARNING

root:
  level: INFO
  handlers: [console]

disable_existing_loggers: false
EOH

      }
      template {
        destination = "local/discord.yaml"
        change_mode = "restart"
        data        = <<EOH
id: discord
url: http://{{ range service "matrix-discord-bridge" }}{{ .Address }}:{{ .Port }}{{ end }}
as_token: "{{ key "matrix/bridge/discord/as_token" }}"
hs_token: "{{ key "matrix/bridge/discord/hs_token" }}"
sender_localpart: discordbot
rate_limited: false
namespaces:
  users:
    - exclusive: true
      regex: '@.*_d:redbrick\.dcu\.ie'
  rooms: []
  aliases:
    - exclusive: false
      # regex: '#.*_d:redbrick\.dcu\.ie'
      regex: '#.*:redbrick\.dcu\.ie'
EOH
      }
    }
    task "wait-for-db" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "postgres:17-alpine"
        command = "sh"
        args = [
          "-c",
          "while ! pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER}; do echo 'Waiting for DB...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        destination = "local/wait.env"
        env         = true
        data        = <<EOH
{{- range service "matrix-postgres" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
DB_USER={{ key "matrix/db/user" }}
EOH
      }

      resources {
        memory = 128
      }
    }
  }

  group "postgres" {
    count = 1

    update {
      max_parallel = 0 # don't update this group automatically
      auto_revert  = false
    }

    network {
      port "db" {
        to = 5432
      }
    }

    service {
      name = "matrix-postgres"
      port = "db"

      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "db" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data"
        ]
      }

      template {
        destination = "secrets/postgres.env"
        env         = true
        data        = <<-EOH
POSTGRES_DB           = {{ key "matrix/db/name" }}
POSTGRES_USER         = {{ key "matrix/db/user" }}
POSTGRES_PASSWORD     = {{ key "matrix/db/password" }}
POSTGRES_INITDB_ARGS  =--encoding=UTF8 --lc-collate=C --lc-ctype=C
EOH
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
