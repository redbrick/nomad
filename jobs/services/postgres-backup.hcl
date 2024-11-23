job "postgres-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */3 * * * *"]
    prohibit_overlap = true
  }

  group "db-backup" {
    task "postgres-backup" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/script.sh"]
      }

      template {
        data        = <<EOH
#!/bin/bash

file=/storage/backups/nomad/postgres/postgres-$(date +%Y-%m-%d_%H-%M-%S).sql

mkdir -p /storage/backups/nomad/postgres

alloc_id=$(nomad job status postgres | grep running | tail -n 1 | cut -d " " -f 1)

job_name=$(echo ${NOMAD_JOB_NAME} | cut -d "/" -f 1)

nomad alloc exec $alloc_id pg_dumpall -U {{ key "postgres/username/root" }} > "${file}"

find /storage/backups/nomad/postgres/postgres* -ctime +3 -exec rm {} \; || true

if [ -s "$file" ]; then # check if file exists and is not empty
  echo "Backup successful"
  exit 0
else
  rm $file
  curl -H "Content-Type: application/json" -d \
  '{"content": "<@&585512338728419341> `PostgreSQL` backup for **'"${job_name}"'** has just **FAILED**\nFile name: `'"$file"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
  {{ key "postgres/webhook/discord" }}
fi
EOH
        destination = "local/script.sh"
      }
    }
  }
}

