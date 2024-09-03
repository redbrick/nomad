job "bastion-vm-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */3 * * * *"]
    prohibit_overlap = true
  }

  group "vm-backup" {

    task "qcow-backup" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/script.sh"]
      }

      resources {
        cpu    = 3000
        memory = 1000
      }

      template {
        data        = <<EOH
#!/bin/bash

path=/storage/backups/nomad/bastion-vm
file=bastion-vm-$(date +%Y-%m-%d_%H-%M-%S).qcow2

mkdir -p ${path}

host=$(nomad job status -verbose bastion-vm | grep running | tail -n 1 | cut -d " " -f 7)

alloc_id=$(nomad job status -verbose bastion-vm | grep running | tail -n 1 | cut -d " " -f 1)

job_name=$(echo ${NOMAD_JOB_NAME} | cut -d "/" -f 1)

echo "Backing up alloc id: ${alloc_id} on: ${host} to ${path}/${file}..."
scp -B -i {{ key "bastion-vm/service/key" }} {{ key "bastion-vm/service/user" }}@${host}:/opt/nomad/alloc/${alloc_id}/bastion-vm/local/bastion-vm.qcow2 ${path}/${file}

find ${path}/bastion-vm-* -ctime +2 -exec rm {} \; || true

size=$(stat -c%s "${path}/${file}")

if [ ${size} -gt 4000000000 ]; then # check if file exists and is not empty
  echo "Updating latest symlink to ${file}..."
  ln -sf ./${file} ${path}/bastion-vm-latest.qcow2
  echo "Backup successful"
  exit 0
else
  rm $file
  curl -H "Content-Type: application/json" -d \
  '{"content": "## <@&585512338728419341> `VM` backup for **'"${job_name}"'** has just **FAILED**\nFile name: `'"$file"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
  {{ key "bastion-vm/webhook/discord" }}
fi
EOH
        destination = "local/script.sh"
      }
    }
  }
}

