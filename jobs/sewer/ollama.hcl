job "ollama" {
  datacenters = ["sewer"]
  type        = "system"

  group "ollama" {
    network {
      port "ollama" {
        static       = 11434
        to           = 11434
        host_network = "lan"
      }
    }

    task "ollama" {
      driver = "docker"

      config {
        image = "ollama/ollama"
        ports = ["ollama"]
        volumes = [
          "/mnt/ollama:/root/.ollama",
        ]
      }

      resources {
        cpu    = 2000
        memory = 49152

        device "gpu" {
          count = 1
        }
      }
    }
  }
}