# Redbrick Ansible Playbook

To run various roles, make sure you edit the `redbrick-ansible.yml` playbook and comment out whatever roles you do not want to run.

This playbook is supposed to used as a starting base, extend or modify it as you see fit. I would suggest you create a copy of it and add that file to the `.gitignore` file so that you're not constantly reverting your changes.

## Running

Below is an example of how to run this playbook:

```bash
$ ansible-playbook -i hosts redbrick-ansible.yml
```

This command assumes `hosts` is your hosts file, you can copy the sample host file and modify the credentials in `group_vars`

## Examples

### Adding new users to aperture

When you want to add a new user to all of the aperture servers, run the below command. You'll also need to edit [`roles/ssh/defaults/main.yml`](./roles/ssh/defaults/main.yml).

```
ansible-playbook -i hosts redbrick-ansible.yml -e "created_users_pass=hellothere"
```

## Contributing

Please add all roles into the `roles` directory, following the same directory structure.

You should also add the role and a small description of what it does into `redbrick-ansible.yml`, this is to make it easier to run commands and modify the playbook at a glance.

If you have any questions, please mail/ping `distro` in Redbrick.

