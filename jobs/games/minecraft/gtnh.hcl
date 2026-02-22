job "minecraft-gtnh" {
  datacenters = ["aperture"]
  type        = "service"

  group "gtnh-mc" {
    count = 1

    network {
      port "mc" {
        to = 25565
      }
      port "rcon" {
        to = 25575
      }
      port "bluemap" {
        to = 8100
      }
    }

    service {
      name = "gtnh-mc"
      port = "mc"
    }

    service {
      name = "gtnh-mc-rcon"
      port = "rcon"
    }

    task "minecraft" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server:java25"
        ports = ["mc", "rcon", "bluemap"]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/data",
          "local/server:/server",
        ]
      }

      resources {
        cpu    = 5000  # 5000 MHz
        memory = 20480 # 20 GB
      }

      artifact {
        source      = "https://downloads.gtnewhorizons.com/ServerPacks/GT_New_Horizons_2.8.4_Server_Java_17-25.zip"
        destination = "local/server"
        options {
          archive = false
        }

      }

      template {
        data        = <<EOF
EULA                            = "TRUE"
TYPE                            = "CUSTOM"
GENERIC_PACK                    = "/server/GT_New_Horizons_2.8.4_Server_Java_17-25.zip"
SKIP_GENERIC_PACK_UPDATE_CHECK  = "true"
CUSTOM_SERVER                   = "lwjgl3ify-forgePatches.jar"
# VERSION                       = "1.21.11"
MEMORY                          = 18G
JVM_OPTS                        = "-Dfml.readTimeout=180 @java9args.txt"
MOTD                            = "Redbrick GTNH"
ICON                            = "https://docs.redbrick.dcu.ie/res/logo.png"
DIFFICULTY                      = "normal"
ENABLE_COMMAND_BLOCK            = "TRUE"
MAX_PLAYERS                     = 12
VIEW_DISTANCE                   = 12
MODE                            = 0
LEVEL_TYPE                      = "rwg"
ALLOW_FLIGHT                    = "TRUE"
DUMP_SERVER_PROPERTIES          = "TRUE"
ENABLE_RCON                     = "TRUE"
RCON_PASSWORD                   = {{ key "games/mc/gtnh-mc/rcon/password" }}
SPAWN_PROTECTION                = 1
EOF
        destination = "local/.env"
        env         = true
      }
    }
  }
}
