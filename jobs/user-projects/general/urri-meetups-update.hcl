job "urri-meetups-update" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */6 * * * *"]
    prohibit_overlap = true
  }

  group "urri-meetups-update" {

    task "urri-meetups-update" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/script.sh"]
      }

      template {
        data        = <<EOH
#!/bin/bash

# stop the urri-meetups job
nomad job stop urri-meetups
sleep 1
# revert the urri-meetups job to the previous version
# this will trigger a new deployment, which will pull the latest image
nomad job revert urri-meetups $(($(nomad job inspect urri-meetups | jq '.Job.Version')-1))
EOH
        destination = "local/script.sh"
      }
    }
  }
}

