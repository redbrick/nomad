job "matrix-hydrogen" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "matrix.redbrick.dcu.ie"
    main   = "redbrick.dcu.ie"
  }

  group "hydrogen" {
    count = 1

    network {

      port "http" {
        to = 8080
      }
    }

    service {
      name = "matrix-hydrogen-web"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.matrix-hydrogen-web.rule=Host(`hydrogen.redbrick.dcu.ie`)",
        "traefik.http.routers.matrix-hydrogen-web.entrypoints=websecure",
        "traefik.http.routers.matrix-hydrogen-web.tls=true",
        "traefik.http.routers.matrix-hydrogen-web.tls.certresolver=rb",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "hydrogen" {
      driver = "docker"

      config {
        image = "ghcr.io/element-hq/hydrogen-web:latest"
        ports = ["http"]

        volumes = [
          "local/config.json:/config.json.bundled:ro" # NOTE: the docker image copies this file to /config.json on startup
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      template {
        destination = "local/config.json"
        change_mode = "restart"
        data        = <<EOH
{
  "defaultHomeServer": "https://redbrick.dcu.ie",
  "themeManifests": [
    "assets/theme-element.json"
  ],
  "defaultTheme": {
    "light": "element-light",
    "dark": "element-dark"
  }
}
EOH
      }
    }
  }
}
