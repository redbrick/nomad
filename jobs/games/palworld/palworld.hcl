job "palworld-server" {
  datacenters = ["aperture"]
  type        = "service"

  constraint {
    attribute = "${meta.ingress_vip_node}"
    value     = "1"
  }

  group "palworld" {
    count = 1

    network {
      mode = "bridge"

      port "game" {
        to = 8211
      }
      port "query" {
        to = 27015
      }
    }

    service {
      name = "palworld-game"
      port = "game"
      task = "server"

      tags = [
        "traefik.enable=true",
        "traefik.udp.routers.palworld-game.entrypoints=palworld-game",
      ]
    }

    service {
      name = "palworld-query"
      port = "query"
      task = "server"
      
      tags = [
        "traefik.enable=true",
        "traefik.udp.routers.palworld-query.entrypoints=palworld-query",
      ]
    }

    task "server" {
      driver = "docker"

      config {
        image = "thijsvanloef/palworld-server-docker:latest"

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/palworld"
        ]
      }

      env {
        PORT                       = "8211"
        QUERY_PORT                 = "27015"
        PLAYERS                    = "32"
        ENABLE_PERF_THREADING_ARGS = "true"
        RCON_ENABLED               = "true"
        RCON_PORT                  = "25575"
        IS_MULTIPLAY               = "true"
        PUID                       = "1000"
        PGID                       = "1000"
        UPDATE_ON_BOOT             = "true"
        BACKUP_ENABLED             = "true"
        BACKUP_CRON_EXPRESSION     = "0 */1 * * *"

        # Note: Fixed variable typo below (changed AUTO_UPDATES_ENABLED to AUTO_UPDATE_ENABLED to match image standard)
        AUTO_UPDATE_ENABLED         = "true"
        AUTO_UPDATE_CRON_EXPRESSION = "0 * * * *"
        AUTO_UPDATE_WARN_MINUTES    = "30"

        SERVER_IP          = "0.0.0.0"
        PUBLIC_IP          = "136.206.16.50"
        SERVER_NAME        = "Redbrick Palworld Server"
        SERVER_DESCRIPTION = "..."
        LOG_LEVEL          = "INFO"
      }

      template {
        data        = <<EOH
ADMIN_PASSWORD={{ key "games/palworld/admin_password" }}
EOH
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 4000
        memory = 32768
      }
    }
  }
}
