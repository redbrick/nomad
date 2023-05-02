job "create-astral" {
  datacenters = ["aperture"]
  type = "service"

  group "mc" {
    constraint {
        attribute = "${attr.unique.hostname}"
        value = "glados"
    }

    count = 1
    network {
      port "mc-vanilla-port" {
        static = 25565
        to = 25565
      }
      port "mc-vanilla-rcon" {
        to = 25575
      }
      #mode = "bridge"
    }

    service {
      name = "minecraft-vanilla"
    }

    task "minecraft-server" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc-vanilla-port","mc-vanilla-rcon"]
      }

      resources {
        cpu    = 3000 # 500 MHz
        memory = 6144 # 6gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
      }
    }
  }

  group "mc-astral" {
    constraint {
        attribute = "${attr.unique.hostname}"
        value = "glados"
    }

    count = 1
    network {
      port "mc-astral-port" {
        static = 25566
        to = 25565
      }
      port "mc-astral-rcon" {
        to = 25575
      }
      mode = "bridge"
    }

    service {
      name = "minecraft-astral"
    }

    task "minecraft-astral" {
      driver = "docker"
      config {
        image = "itzg/minecraft-server"
        ports = ["mc-astral-port","mc-astral-rcon"]
        volumes = [
          "data:/data"
        ]
      }

      resources {
        cpu    = 3000 # 500 MHz
        memory = 6144 # 6gb
      }

      env {
        EULA = "TRUE"
        MEMORY = "6G"
        TYPE = "FORGE"
        VERSION = "1.18.2"
        CF_SERVER_MOD = "modpack.zip"
      }

      artifact {
        source = "http://10.10.0.5:8000/modpack.zip"
        destination = "/data"
        options {
          archive = false
        }
      }
    }
  }
}
