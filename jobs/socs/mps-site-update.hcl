job "mps-site-update" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */6 * * * *"]
    prohibit_overlap = true
  }

  group "mps-site-update" {

    task "mps-site-update" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/script.sh"]
      }

      template {
        data = <<EOH
#!/bin/bash

# stop the mps-site job
nomad job stop mps-site
sleep 1
# revert the mps-site job to the previous version
# this will trigger a new deployment, which will pull the latest image
nomad job revert mps-site $(($(nomad job inspect mps-site | jq '.Job.Version')-1))
EOH
        destination = "local/script.sh"
      }
    }
  }
}

