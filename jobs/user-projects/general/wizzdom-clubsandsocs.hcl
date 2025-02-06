job "cands-room-bookings" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    git-sha = ""
  }

  group "clubsandsocs-room-bookings" {
    count = 1

    network {
      port "http" {
        to = 5000
      }
    }

    service {
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.clubsandsocs-room-bookings.rule=Host(`rooms.rb.dcu.ie`)",
        "traefik.http.routers.clubsandsocs-room-bookings.entrypoints=web,websecure",
        "traefik.http.routers.clubsandsocs-room-bookings.tls.certresolver=lets-encrypt",
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image      = "ghcr.io/wizzdom/clubsandsocs-room-bookings:latest"
        ports      = ["http"]
        force_pull = true
        volumes = [
          "local/.env:/app/.env"
        ]
      }

      template {
        data        = <<EOF
UPLOAD_FOLDER=uploads
SECRET_KEY={{ key "user-projects/wizzdom/clubsandsocs-room-bookings/secret" }}
EOF
        destination = "local/.env"
      }
      resources {
        cpu    = 1000
        memory = 800
      }
    }
  }
}
