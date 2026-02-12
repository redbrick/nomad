job "matrix-cinny" {
  datacenters = ["aperture"]
  type        = "service"


  group "cinny" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "cinny-web"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.cinny.rule=Host(`cinny.redbrick.dcu.ie`)",
        "traefik.http.routers.cinny.entrypoints=websecure",
        "traefik.http.routers.cinny.tls=true",
        "traefik.http.routers.cinny.tls.certresolver=rb",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "cinny" {
      driver = "docker"

      config {
        image = "ghcr.io/cinnyapp/cinny:latest"
        ports = ["http"]

        volumes = [
          "local/config.json:/app/config.json:ro"
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
      "#cinny-space:matrix.org"
    ],
    "rooms": [
      "#cinny:matrix.org"
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
