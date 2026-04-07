job "gatus" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "status.redbrick.dcu.ie"
  }

  group "db-web" {
    count = 1

    network {
      port "db" {
        to = 5432
      }
    }

    service {
      name = "gatus-db"
      port = "db"

      check {
        name     = "postgres-tcp"
        type     = "tcp"
        port     = "db"
        interval = "10s"
        timeout  = "2s"
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
        destination = "local/.env"
        env = true
        data = <<EOH
POSTGRES_DB       = {{ key "gatus/db/name" }}
POSTGRES_USER     = {{ key "gatus/db/user" }}
POSTGRES_PASSWORD = {{ key "gatus/db/password" }}
EOH
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "gatus"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.gatus.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.gatus.entrypoints=web,websecure",
        "traefik.http.routers.gatus.tls.certresolver=rb",
      ]
    }

    task "wait-for-db" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine:3.19"
        command = "sh"
        args = [
          "-c",
          "while ! nc -z \"$DB_HOST\" \"$DB_PORT\"; do echo 'Waiting for DB...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        destination = "local/.env"
        env = true
        change_mode = "restart"
        data = <<EOH
{{- range service "gatus-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
EOH
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "gatus" {
      driver = "docker"

      config {
        image = "twinproduction/gatus:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/config",
          "local/config.yaml:/config/config.yaml",
        ]
      }

      template {
        destination = "local/config.yaml"
        data        = <<EOH
ui:
  title: "Redbrick Status"
  description: "Status and uptime for Redbrick's Services and Servers"
  header: "Status"
  dashboard-heading: "Health Dashboard"
  dashboard-subheading: "Centralised dashboard to monitor all Redbrick's running services and track downtime"
  logo: "https://redbrick.dcu.ie/assets/favicon.ico"
  link: "https://{{ env "NOMAD_META_domain" }}"
  ui.favicon.default: "https://redbrick.dcu.ie/assets/favicon.ico"
  dark-mode: on

storage:
  type: postgres
  path: '{{- range service "gatus-db" -}}postgres://{{ key "gatus/db/user" | urlquery }}:{{ key "gatus/db/password" | urlquery }}@{{ .Address }}:{{ .Port }}/{{ key "gatus/db/name" | urlquery }}?sslmode=disable{{- end -}}'

alerting:
  discord:
    webhook-url: '{{ key "gatus/discord/webhook/url" }}'
    default-alert:
      enabled: true
      send-on-resolved: true
      failure-threshold: 3
      success-threshold: 2

defaults_tcp: &defaults_tcp
  interval: 60s
  alerts:
      - type: discord
  conditions:
      - "[CONNECTED] == true"

defaults: &defaults
  interval: 60s
  alerts:
    - type: discord
  conditions:
    - "[STATUS] == 200"

defaults_https: &defaults_https
  <<: *defaults
  conditions:
    - "[STATUS] == 200"
    - "[CERTIFICATE_EXPIRATION] > 48h"

endpoints:
  # --- All Redbrick Monitors ---
  - name: Atlas
    group: Services
    url: "https://redbrick.dcu.ie"
    <<: *defaults_https

  - name: RB Wiki
    group: Services
    url: "https://wiki.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Admin API
    group: Services
    url: "https://api.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Better Timetable
    group: Services
    url: "https://timetable.redbrick.dcu.ie"
    <<: *defaults_https

  - name: The College View
    group: Services
    url: "https://thecollegeview.ie"
    <<: *defaults_https

  - name: The Look
    group: Services
    url: "https://thelookonline.dcu.ie"
    <<: *defaults_https

  - name: Hedgedoc
    group: Services
    url: "https://md.redbrick.dcu.ie/_health"
    <<: *defaults_https

  - name: DCU Solar Racing
    group: Other Socs
    url: "https://solarracing.ie"
    <<: *defaults_https

  - name: MPS Site
    group: Other Socs
    url: "https://dcumps.ie"
    <<: *defaults_https

  - name: Solar Racing Outline
    group: Other Socs
    url: "https://outline.solarracing.ie"
    <<: *defaults_https

  - name: Vaultwarden
    group: Services
    url: "https://vault.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Pastebin
    group: Services
    url: "https://paste.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Plausible
    group: Services
    url: "https://plausible.redbrick.dcu.ie"
    <<: *defaults_https

  - name: RB Docs
    group: Services
    url: "https://docs.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Plume (on RB)
    group: Services
    url: "https://cspp.rb.dcu.ie"
    <<: *defaults_https

  - name: Paperless
    group: Services
    url: "https://paperless.redbrick.dcu.ie"
    <<: *defaults_https

  - name: C&S OMS
    group: Services
    url: "https://dcuclubsandsocs.ie"
    <<: *defaults_https

  - name: C&S Room Bookings
    group: Services
    url: "https://rooms.rb.dcu.ie"
    <<: *defaults_https

  - name: Glados
    group: Servers
    url: "tcp://10.10.0.4:22"
    <<: *defaults_tcp

  - name: Wheatley
    group: Servers
    url: "tcp://10.10.0.5:22"
    <<: *defaults_tcp

  - name: Bastion VM
    group: Servers
    url: "tcp://136.206.16.50:2269"
    <<: *defaults_tcp

  - name: Johnson
    group: Servers
    url: "tcp://10.10.0.7:22"
    <<: *defaults_tcp

  - name: Chell
    group: Servers
    url: "tcp://10.10.0.6:22"
    <<: *defaults_tcp

  - name: Minecraft Vanilla
    group: Game Servers
    url: "tcp://vanilla-mc.rb.dcu.ie:25565"
    <<: *defaults_tcp

  - name: Discord Shortlink
    group: Short Links
    url: "https://discord.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Github Shortlink
    group: Short Links
    url: "https://github.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Instagram Shortlink
    group: Short Links
    url: "https://instagram.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Youtube Shortlink
    group: Short Links
    url: "https://youtube.redbrick.dcu.ie"
    <<: *defaults_https

  - name: LinkedIn Shortlink
    group: Short Links
    url: "https://linkedin.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Twitch Shortlink
    group: Short Links
    url: "https://twitch.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Tiktok Shortlink
    group: Short Links
    url: "https://tiktok.redbrick.dcu.ie"
    <<: *defaults_https

  - name: Amikon Website
    group: Short Links
    url: "https://amikon.me"
    <<: *defaults_https

  - name: DCU Clubs and Socs
    group: Short Links
    url: "https://dcuclubsandsocs.ie"
    <<: *defaults_https
EOH
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}