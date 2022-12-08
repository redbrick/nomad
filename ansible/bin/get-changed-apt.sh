#!/bin/bash

ansible -m shell -i hosts all -a "cmd='grep -E \"^$(date +%Y-%m-%d).+ (install|upgrade) \" /var/log/dpkg.log | cut -d \" \" -f 3-5'"
