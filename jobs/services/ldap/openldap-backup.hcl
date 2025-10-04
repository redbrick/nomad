job "openldap-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */3 * * * *"]
    prohibit_overlap = true
  }

  group "ldap-backup" {
    task "ldap-backup" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/script.sh"]
      }

      template {
        data        = <<EOH
#!/bin/bash

job_name=$(echo ${NOMAD_JOB_NAME} | cut -d "/" -f 1)

file=/storage/backups/nomad/${job_name}/${job_name}-$(date +%Y-%m-%d_%H-%M-%S).ldif.gpg

mkdir -p /storage/backups/nomad/${job_name}

alloc_id=$(nomad job status openldap | grep running | tail -n 1 | cut -d " " -f 1)


nomad alloc exec -task=openldap $alloc_id slapcat -F /bitnami/openldap/slapd.d -n 2

find /storage/backups/nomad/${job_name}/${job_name}* -ctime +3 -exec rm {} \; || true

if [ -s "$file" ]; then # check if file exists and is not empty
  echo "Backup successful"
  exit 0
else
  rm $file
  curl -H "Content-Type: application/json" -d \
  '{"content": "<@&585512338728419341> `OPENLDAP` backup for **'"${job_name}"'** has just **FAILED**\nFile name: `'"$file"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
  {{ key "mysql/webhook/discord" }}
fi
EOH
        destination = "local/script.sh"
      }
    }
  }
}

