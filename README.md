# Redbrick Nomad Configs and Ansible Scripts

This repo contains all of Redbrick's infrastructure that is deployed through Hashicorp's Nomad and uses ansible to configure and manage the hosts.

## Nomad

All Nomad job related configurations are stored in the `nomad` directory.

The terminology used here is explained [here](https://developer.hashicorp.com/nomad/tutorials/get-started/get-started-vocab). This is **required reading**.

All of the job files are stored in the `nomad` directory. To deploy a Nomad job manually, connect to a host and run

```bash
$ nomad job plan path/to/job/file.hcl
```

This will plan the allocations and ensure that what is deployed is the correct version.

If you are happy with the deployment, run

```bash
$ nomad job run -check-index [id from last command] path/to/job/file.hcl
```

This will deploy the planned allocations, and will error if the file changed on disk between the plan and the run.

You can shorten this command to just

```bash
$ nomad job plan path/to/file.hcl | grep path/to/file.hcl | bash
```

This will plan and run the job file without the need for you to copy and paste the check index id. Only use this once you are comfortable with how Nomad places allocations.

## Ansible

Ansible can be used to provision a new host, connect a host to the cluster, run new jobs and more.

Install ansible from [here](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

In order to use ansible from your local machine, you must have access to the admin VPN. This will allow you direct connection to each of the hosts.

Move the `ansible/group_vars/all.yml.sample` file to `ansible/group_vars/all.yml` and change your local username before you run any of these playbooks. Your local user should have an SSH key in its home dir, which can be configured with the `ssh` playbook.

```bash
$ ansible-playbook -i hosts redbrick-ansible.yml 
```
