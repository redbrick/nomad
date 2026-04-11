job "minecraft-wilko" {
  datacenters = ["aperture"]
  type        = "service"

  group "wilko-mc" {
    count = 1

    network {
      port "mc" {
        to = 25565
      }
      port "rcon" {
        to = 25575
      }
      port "dynmap" {
        to = 8123
      }
    }

    service {
      name = "wilko-mc"
      port = "mc"
    }

    service {
      name = "wilko-mc-rcon"
      port = "rcon"
    }

    service {
      name = "wilko-mc-dynmap"
      port = "dynmap"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.wilko-mc-dynmap.rule=Host(`wilko-mc.rb.dcu.ie`)",
        "traefik.http.routers.wilko-mc-dynmap.entrypoints=web,websecure",
        "traefik.http.routers.wilko-mc-dynmap.tls.certresolver=rb",
      ]
    }

    task "minecraft" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server:java21"
        ports = ["mc", "rcon", "dynmap"]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/data",
          "local/plugins:/plugins",
          "local/mods:/mods",
        ]
      }

      resources {
        cpu    = 5000  # 5000 MHz
        memory = 20480 # 20 GB
      }

      # Server Settings/Enviorments block
      template {
        destination = "local/.env"
        env         = true
        data        = <<EOF
EULA              = "TRUE"
TYPE              = "PAPER"
VERSION           = "1.21.4"
ICON              = "https://docs.redbrick.dcu.ie/res/logo.png"
MAX_MEMORY        = "18G"
MOTD              = "Wilko Redbrick Server"
MAX_PLAYERS       = "32"
VIEW_DISTANCE     = "16"
ENABLE_RCON       = "true"
RCON_PASSWORD     = "{{ key "games/mc/wilko-mc/rcon/password" }}"
SPAWN_PROTECTION  = "0"
OPS               = "CatcherOfFish,flyhighdragon"
SPIGET_RESOURCES = 34315 # Vault
MODRINTH_PROJECTS = worldedit,dynmap:ImNNT17B,stairsit,multiverse-core,datapack:veinminer,essentialsx,essentialsx-chat-module,essentialsx-spawn
EOF
      }
    }
  }
}