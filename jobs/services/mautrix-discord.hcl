job "matrix-discord-bridge" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "discord-appservice.redbrick.dcu.ie"
  }

  group "discord-bridge" {
    count = 1

    network {
      port "appservice" {
        to = 29334
      }
    }

    service {
      name = "matrix-discord-bridge"
      port = "appservice"

      # check {
      #   type     = "http"
      #   interval = "30s"
      #   timeout  = "5s"
      # }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.matrix-discord-bridge.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.matrix-discord-bridge.entrypoints=websecure",
        "traefik.http.routers.matrix-discord-bridge.tls=true",
        "traefik.http.routers.matrix-discord-bridge.tls.certresolver=rb",
      ]
    }

    task "mautrix-discord" {
      driver = "docker"

      restart {
        attempts = 20
        delay    = "10s"
        interval = "10m"
        mode     = "delay"
      }

      config {
        image   = "dock.mau.dev/mautrix/discord:latest"
        ports   = ["appservice"]
        command = "sh"
        args    = ["-c", "cd /data && /usr/bin/mautrix-discord --no-update"]

        volumes = [
          "local/config.yaml:/data/config.yaml",
        ]
      }

      resources {
        cpu    = 500
        memory = 512
      }

      template {
        destination = "local/config.yaml"
        change_mode = "restart"
        data        = <<EOH
# Homeserver details
homeserver:
  address: https://matrix.redbrick.dcu.ie
  domain: redbrick.dcu.ie
  software: standard
  status_endpoint: null
  message_send_checkpoint_endpoint: null
  async_media: false
  websocket: false

# Application service host/registration related details
appservice:
  address: http://0.0.0.0:29334
  hostname: 0.0.0.0
  port: 29334

  id: discord
  bot_username: discordbot
  bot_displayname: Discord Bridge Bot
  bot_avatar: mxc://maunium.net/nIdEykemnwdisvHbpxflpDlC

  ephemeral_events: true
  async_transactions: false

  as_token: "{{ key "matrix/bridge/discord/as_token" }}"
  hs_token: "{{ key "matrix/bridge/discord/hs_token" }}"

# Database config
  database:
    type: postgres
    uri: postgres://{{ key "matrix/bridge/discord/db/user" }}:{{ key "matrix/bridge/discord/db/password" }}@{{ if service "mautrix-discord-postgres" }}{{ with index (service "mautrix-discord-postgres") 0 }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}/{{ key "matrix/bridge/discord/db/name" }}?sslmode=disable

# Bridge config
bridge:
  username_template: "{{ "{{.}}" }}_d"
  displayname_template: "{{ "{{.GlobalName}}" }} (Discord)"
  channel_name_template: "{{ "{{.Name}}" }}"
  guild_name_template: '{{.Name}}'

  # Personal filtering spaces
  personal_filtering_spaces: true

  # Enable relay mode for webhook-based bridging
  relay:
    enabled: true
    default_relays: []
    message_formats:
      m.text: "{{ "{{.Sender.Displayname}}" }}: {{ "{{.Message}}" }}"
      m.notice: "{{ "{{.Sender.Displayname}}" }}: {{ "{{.Message}}" }}"
      m.emote: "* {{ "{{.Sender.Displayname}}" }} {{ "{{.Message}}" }}"
      m.file: "{{ "{{.Sender.Displayname}}" }} sent a file"
      m.image: "{{ "{{.Sender.Displayname}}" }} sent an image"
      m.audio: "{{ "{{.Sender.Displayname}}" }} sent an audio file"
      m.video: "{{ "{{.Sender.Displayname}}" }} sent a video"
      m.location: "{{ "{{.Sender.Displayname}}" }} sent a location"

  # Permissions
  permissions:
    "redbrick.dcu.ie": relay
    "{{ key "matrix/bridge/discord/admin_user" }}": admin
    "@matrix:redbrick.dcu.ie": admin

  bot_token: "{{ key "matrix/bridge/discord/bot_token" }}"

  # Discord bot config
  guild_name_template: "{{ "{{.Name}}" }}"
  use_discord_cdn_upload: true
  enable_webhook_avatars: true
  custom_emoji_reactions: true
  public_address: https://{{ env "NOMAD_META_domain" }}
  avatar_proxy_key: generate
  # Settings for backfilling messages.
  backfill:
    # Limits for forward backfilling.
    forward_limits:
      # Initial backfill (when creating portal). 0 means backfill is disabled.
      # A special unlimited value is not supported, you must set a limit. Initial backfill will
      # fetch all messages first before backfilling anything, so high limits can take a lot of time.
      initial:
        dm: 0
        channel: -1
        thread: 0
      # Missed message backfill (on startup).
      # 0 means backfill is disabled, -1 means fetch all messages since last bridged message.
      # When using unlimited backfill (-1), messages are backfilled as they are fetched.
      # With limits, all messages up to the limit are fetched first and backfilled afterwards.
      missed:
        dm: 0
        channel: -1
        thread: 0
    # Maximum members in a guild to enable backfilling. Set to -1 to disable limit.
    # This can be used as a rough heuristic to disable backfilling in channels that are too active.
    # Currently only applies to missed message backfill.
    max_guild_members: -1

# Logging config
logging:
  min_level: info
  writers:
    - type: stdout
      format: pretty-colored
      time_format: "2006-01-02 15:04:05"
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
{{- range service "mautrix-discord-postgres" }}
DB_HOST = {{ .Address }}
DB_PORT = {{ .Port }}
{{- end }}
DB_USER = {{ key "matrix/bridge/discord/db/user" }}
EOH
      }

      resources {
        memory = 128
      }
    }
  }

  group "postgres" {
    count = 1

    network {
      port "db" {
        to = 5432
      }
    }

    service {
      name = "mautrix-discord-postgres"
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
        data        = <<EOH
POSTGRES_DB           = {{ key "matrix/bridge/discord/db/name" }}
POSTGRES_USER         = {{ key "matrix/bridge/discord/db/user" }}
POSTGRES_PASSWORD     = {{ key "matrix/bridge/discord/db/password" }}
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
