#!/bin/bash

sudo chown -R root:nomad ./

sudo find . -type d -exec chmod 775 {} \;

sudo find . -type f -exec chmod 664 {} \;

echo "use sudo and distro finds you"
