job "minecraft-cjaran" {
  datacenters = ["aperture"]
  type        = "service"

  group "cjaran-mc" {
    count = 1

    network {
      port "mc" {
        static = 25571
        to     = 25565
      }

      port "rcon" {
        to = 25575
      }
    }

    service {
      name = "cjaran-mc"
      port = "mc"
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

      env {
        EULA            = "TRUE"
        TYPE            = "PAPER"
        VERSION         = "1.20.4"
        USE_AIKAR_FLAGS = true
        OPS             = "BloThen"
        MAX_PLAYERS     = "10"
      }
    }
  }
}
