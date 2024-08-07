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

    task "minecraft-vanilla" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc-vanilla-port","mc-vanilla-rcon"]
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 8192 # 8GB
      }

      env {
        EULA = "TRUE"
        TYPE = "PAPER"
        ICON = "https://docs.redbrick.dcu.ie/assets/logo.png"
        USE_AIKAR_FLAGS=true
        MOTD = "LONG LIVE THE REDBRICK"
        MAX_PLAYERS = "20"
      }
    }
  }

  group "fugitives-mc" {
    count = 1

    network {
      port "mc-fugitives-port" {
        static = 25570
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
        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 8192 # 8GB
      }

      env {
        EULA = "TRUE"
        TYPE = "PAPER"
        USE_AIKAR_FLAGS=true
        MOTD = "Fugitives"
        MAX_PLAYERS = "20"
        MEMORY = "6G"
      }
    }
  }

  group "games-mc" {
    count = 1

    network {
      port "mc-games-port" {
        static = 25569
        to = 25565
      }

      port "mc-games-rcon" {
        to = 25575
      }
    }

    service {
      name = "games-mc"
    }

    task "minecraft-games" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-games-port","mc-games-rcon"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 8192 # 8GB
      }

      env {
        EULA = "TRUE"
        TYPE = "PURPUR"
        VERSION = "1.20.1"
        MOTD = "DCU Games Soc Minecraft Server"
        USE_AIKAR_FLAGS=true
        OPS = ""
        MAX_PLAYERS = "20"
      }
    }
  }
  group "olim909-mc" {
    count = 1

    network {
      port "mc-olim909-port" {
        static = 25568
        to = 25565
      }

      port "mc-olim909-rcon" {
        to = 25575
      }
      port "mc-olim909-geyser" {
        to = 19132
      }
    }

    service {
      name = "olim909-mc"
    }

    task "minecraft-olim909" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-olim909-port","mc-olim909-rcon","mc-olim909-geyser"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 4096 # 4GB
      }

      env {
        EULA = "TRUE"
        TYPE = "PAPER"
        VERSION = "1.20.4"
        USE_AIKAR_FLAGS=true
        OPS = "Olim909"
        MAX_PLAYERS = "5"
      }
    }
  }

  group "regaus-mc" {
    count = 1

    network {
      port "mc-regaus-port" {
        static = 25566
        to = 25565
      }

      port "mc-regaus-rcon" {
        to = 25575
      }
    }

    service {
      name = "regaus-mc"
    }

    task "minecraft-regaus" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-regaus-port","mc-regaus-rcon"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 4096 # 4GB
      }

      env {
        EULA = "TRUE"
        TYPE = "PAPER"
        VERSION = "1.20.4"
        USE_AIKAR_FLAGS=true
        OPS = "regaus"
        MAX_PLAYERS = "5"
      }
    }
  }

  group "cjaran-mc" {
    count = 1

    network {
      port "mc-cjaran-port" {
        static = 25571
        to = 25565
      }

      port "mc-cjaran-rcon" {
        to = 25575
      }
    }

    service {
      name = "cjaran-mc"
    }

    task "minecraft-cjaran" {
      driver = "docker"

      config {
        image = "itzg/minecraft-server"
        ports = ["mc-cjaran-port","mc-cjaran-rcon"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data"
        ]
      }

      resources {
        cpu    = 3000 # 3000 MHz
        memory = 4096 # 4GB
      }

      env {
        EULA = "TRUE"
        TYPE = "PAPER"
        ICON = "https://i.imgur.com/HC9cRNf.png"
        VERSION = "1.20.4"
        USE_AIKAR_FLAGS=true
        OPS = "BloThen"
        MAX_PLAYERS = "10"
      }
    }
  }
}

