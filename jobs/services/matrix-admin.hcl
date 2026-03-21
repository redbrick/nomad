job "matrix-admin" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "matrix-admin.redbrick.dcu.ie"
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "matrix-admin-web"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.matrix-admin.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.matrix-admin.entrypoints=websecure",
        "traefik.http.routers.matrix-admin.tls=true",
        "traefik.http.routers.matrix-admin.tls.certresolver=rb",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "admin" {
      driver = "docker"

      config {
        image = "awesometechnologies/synapse-admin:latest"
        ports = ["http"]

        volumes = [
          # "local/config.json:/app/config.json:ro"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      template {
        destination = "local/config.json"
        change_mode = "noop"
        data        = <<EOH
{
  "defaultHomeserver": 0,
  "homeserverList": [
    "redbrick.dcu.ie"
  ],
  "allowCustomHomeservers": false,

  "featuredCommunities": {
    "openAsDefault": false,
    "spaces": [
      "#redbrick:redbrick.dcu.ie",
      "#admin-space:matrix.org"
    ],
    "rooms": [
      "#admin:matrix.org"
    ],
    "servers": [
        "reedbrick.dcu.ie",
        "matrix.org",
        "mozilla.org",
        "fosdem.org"
    ]
  },

  "hashRouter": {
    "enabled": false,
    "basename": "/"
  }
}
EOH
      }
    }
  }
}
