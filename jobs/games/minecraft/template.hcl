job "minecraft-SERVICENAME" {
  datacenters = ["aperture"]
  type        = "service"

  group "SERVICENAME-mc" {
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
      name = "SERVICENAME-mc"
      port = "mc"
    }

    service {
      name = "SERVICENAME-mc-rcon"
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
        memory = 8192 # 8 GB
      }

      # Server Settings/Enviorments block
      template {
        destination = "local/.env"
        env         = true
        data        = <<EOF
EULA              = "TRUE"
TYPE              = "PAPER"
VERSION           = "CHANGEME"
ICON              = "https://docs.redbrick.dcu.ie/res/logo.png"
MAX_MEMORY        = "8G"
MOTD              = "A Redbrick Server"
MAX_PLAYERS       = "20"
ENABLE_RCON       = "true"
RCON_PASSWORD     = "{{ key "games/mc/SERVICENAME-mc/rcon/password" }}"
SPAWN_PROTECTION  = "0"
OPS               = "CHANGEME"
EOF
      }
    }
  }
}
