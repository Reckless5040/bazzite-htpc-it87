#!/bin/bash

set -ouex pipefail

# Runs in the throwaway builder stage. Leaves the finished module in /out.

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | tail -n1)"
KSRC="/usr/src/kernels/${KVER}"

### Build dependencies
## kernel-devel ships in Bazzite; make sure it matches the kernel and pull in a toolchain.
if [[ ! -d "${KSRC}" ]]; then
    echo "kernel-devel for ${KVER} not found in the base image" >&2
    exit 1
fi
dnf5 install -y gcc make git-core xz

### Fetch and build the driver
git clone "${IT87_REPO}" /tmp/it87
git -C /tmp/it87 checkout "${IT87_REF}"
make -C /tmp/it87 TARGET="${KVER}" modules

MODULE=/tmp/it87/it87.ko

### Optional module signing (needed when Secure Boot is enabled)
## The private key arrives as a build secret; the matching public cert lives in certs/.
if [[ -s /run/secrets/kmod_key ]]; then
    if [[ ! -s /ctx/certs/it87-mok.der ]]; then
        echo "kmod_key secret given but certs/it87-mok.der is missing" >&2
        exit 1
    fi
    "${KSRC}/scripts/sign-file" sha256 /run/secrets/kmod_key /ctx/certs/it87-mok.der "${MODULE}"
    modinfo "${MODULE}" | grep -q '^signer:'
else
    echo "WARNING: no kmod_key secret, it87 module is UNSIGNED and will not load with Secure Boot on" >&2
fi

### Hand off to the final stage
## updates/ always takes priority over the in-tree kernel/drivers/hwmon/it87.ko.xz
mkdir -p "/out/usr/lib/modules/${KVER}/updates"
xz -f -C crc32 "${MODULE}"
install -m 0644 "${MODULE}.xz" "/out/usr/lib/modules/${KVER}/updates/it87.ko.xz"
git -C /tmp/it87 describe --long --always > /out/it87-version
