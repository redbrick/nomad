job "minecraft" {
  datacenters = ["aperture"]
  type = "service"

  group "vanilla-mc" {
    count = 1

    network {
      port "mc-vanilla-port" {
        static = 25567
        to = 25565
      }
      port "mc-vanilla-rcon" {
        to = 25575
      }
    }

    service {
      name = "vanilla-mc"
    }

    task "minecraft-server" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc-vanilla-port","mc-vanilla-rcon"]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 7168 # 7gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
      }
    }
  }

  group "fugitives-mc" {
    count = 1

    network {
      port "mc-fugitives-port" {
        static = 25566
        to = 25565
      }

      port "mc-fugitives-rcon" {
        to = 25575
      }
    }

    service {
      name = "fugitives-mc"
    }

    task "minecraft-fugitives" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-fugitives-port","mc-fugitives-rcon"]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 8168 # 8gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
      }
    }
  }

  group "shemek-mc" {
    count = 1

    network {
      port "mc-shemek-port" {
        static = 25568
        to = 25565
      }

      port "mc-shemek-rcon" {
        to = 25575
      }
    }

    service {
      name = "shemek-mc"
    }

    task "minecraft-shemek" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-shemek-port","mc-shemek-rcon"]
        
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 7000 # 7000 MHz
        memory = 17408 # 17GB
      }

      env {
        EULA = "TRUE"
        TYPE = "FORGE"
        VERSION = "1.20.1"
        FORGE_INSTALLER = "forge-1.20.1-47.2.19-installer.jar"
        OVERRIDE_SERVER_PROPERTIES = "TRUE"
        JVM_XX_OPTS = "-Xms12G -Xmx16G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"
        MAX_MEMORY = "16G"
        MAX_PLAYERS = "5"
        MOTD = "Minecraft ATM 9"
        DIFFICULTY = "normal"
        SPAWN_PROTECTION = "0"
        ENFORCE_WHITELIST = "true"
        WHITELIST = "Shmickey02"
        OPS = "Shmickey02"
      }
    }
  }
}
