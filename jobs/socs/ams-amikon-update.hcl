job "ams-amikon-update" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */6 * * * *"]
    prohibit_overlap = true
  }

  group "ams-amikon-update" {

    task "ams-amikon-update" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/script.sh"]
      }

      template {
        data = <<EOH
#!/bin/bash

# stop the ams-amikon job
nomad job stop ams-amikon
sleep 1
# revert the ams-amikon job to the previous version
# this will trigger a new deployment, which will pull the latest image
nomad job revert ams-amikon $(($(nomad job inspect ams-amikon | jq '.Job.Version')-1))
EOH
        destination = "local/script.sh"
      }
    }
  }
}

