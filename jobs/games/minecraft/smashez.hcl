job "minecraft-smashez" {
  datacenters = ["aperture"]
  type        = "service"

  group "smashez-mc" {
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
      name = "smashez-mc"
      port = "mc"
    }

    service {
      name = "smashez-mc-rcon"
      port = "rcon"
    }

    task "minecraft" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server:latest"
        ports = ["mc", "rcon"]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/data",
          "local/plugins:/plugins",
          "local/mods:/mods",
        ]
      }

      resources {
        cpu    = 5000 # 5000 MHz
        memory = 12288 # 12 GB
      }

      # Server Settings/Enviorments block
      template {
        destination = "local/.env"
        env         = true
        data        = <<EOF
EULA              = "TRUE"
TYPE              = "FABRIC"
VERSION           = "26.2"
ICON              = "https://docs.redbrick.dcu.ie/res/logo.png"
MAX_MEMORY        = "12G"
MOTD              = "A Redbrick Server"
MAX_PLAYERS       = "20"
ENABLE_RCON       = "true"
RCON_PASSWORD     = "{{ key "games/mc/smashez-mc/rcon/password" }}"
SPAWN_PROTECTION  = "0"
OPS               = "smasherez"
MODRINTH_PROJECTS = "yet-another-minecraft-bingo,fabric-api"
EOF
      }
    }
  }
}
