job "minecraft-games" {
  datacenters = ["aperture"]
  type        = "service"

  group "games-mc" {
    count = 1

    network {
      port "mc" {
        static = 25569
        to     = 25565
      }

      port "rcon" {
        to = 25575
      }
    }

    service {
      name = "games-mc"
      port = "mc"
    }

    task "minecraft-games" {
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
        memory = 8192 # 8GB
      }

      env {
        EULA            = "TRUE"
        TYPE            = "PURPUR"
        VERSION         = "1.20.1"
        MOTD            = "DCU Games Soc Minecraft Server"
        USE_AIKAR_FLAGS = true
        OPS             = ""
        MAX_PLAYERS     = "20"
      }
    }
  }
}
