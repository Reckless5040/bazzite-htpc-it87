#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install the it87 module built in the it87-builder stage
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | tail -n1)"

cp -avf /it87/usr/. /usr/
depmod -a "${KVER}"

# Fail the build if the in-tree driver would still win
modinfo -k "${KVER}" -n it87 | grep -q "/updates/it87.ko"
echo "it87 $(cat /it87/it87-version) installed for ${KVER}"

# Ship the public signing cert so it can be enrolled with mokutil
if [[ -s /ctx/certs/it87-mok.der ]]; then
    install -Dm 0644 /ctx/certs/it87-mok.der /usr/share/bazzite-htpc-it87/it87-mok.der
fi
