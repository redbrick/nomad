job "keepalived" {
  datacenters = ["aperture"]
  node_pool   = "default"
  type        = "system"


  constraint {
    distinct_hosts = true
  }

  group "vrrp" {

    network {
      mode = "host"
    }

    update {
      max_parallel     = 1
      canary           = 1
      min_healthy_time = "10s"
      healthy_deadline = "1m"
      auto_revert      = true
      auto_promote     = true
    }

    task "keepalived" {

      driver = "docker"

      env {
        KEEPALIVED_VIRTUAL_IP   = "136.206.16.50"
        KEEPALIVED_CHECK_PORT   = 8080 # traefik admin port
        KEEPALIVED_VIRTUAL_MASK = 24
        KEEPALIVED_VRID         = 51
        KEEPALIVED_INTERFACE    = "br0" # or auto maybe?
        KEEPALIVED_AUTH_TYPE    = "PASS"
        KEEPALIVED_AUTH_PASS    = "ihatenixos"
      }

      config {
        image        = "shawly/keepalived:2"
        hostname     = "${attr.unique.hostname}"
        network_mode = "host"
        privileged   = true
      }


      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
