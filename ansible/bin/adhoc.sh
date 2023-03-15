#!/bin/bash

if [ $1 = "help" ]; then
  cat << EOH
-- Ad-hoc help --

This command is designed as a helper for running ad-hoc ansible commands.

It takes 2 arguments;
1. The host pattern match, and
2. The module followed by the command to run with that module.

-- Examples --

\$ bin/adhoc.sh all ping
# will run ping on 'all' hosts

\$ bin/adhoc.sh glados shell "cmd='echo hello world'"
# will run the shell module on the 'glados' host
EOH
exit 0
fi

if [ $# -eq 2 ]; then
  ansible -i hosts $1 -m $2
  exit 0
else
  ansible -i hosts $1 -m $2 -a "${@:3}"
  exit 0
fi
