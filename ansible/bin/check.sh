#!/bin/bash

ansible-playbook redbrick-ansible.yml -i hosts --check --diff
