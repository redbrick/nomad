job "minecraft-cjaran" {
  datacenters = ["aperture"]
  type        = "service"

  group "cjaran-mc" {
    count = 1

    network {
      port "mc" {
        to = 25565
      }

      port "rcon" {
        to = 25575
      }
    }

    service {
      name = "cjaran-mc"
      port = "mc"
    }

    service {
      name = "cjaran-mc-rcon"
      port = "rcon"
    }

    task "minecraft-cjaran" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc", "rcon"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 4096 # 4GB
      }

      template {
        data        = <<EOF
EULA            = "TRUE"
TYPE            = "PAPER"
VERSION         = "1.20.4"
USE_AIKAR_FLAGS = true
OPS             = "BloThen"
MAX_PLAYERS     = "10"
ENABLE_RCON     = true
RCON_PASSWORD   = {{ key "games/mc/cjaran-mc/rcon/password" }}
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
