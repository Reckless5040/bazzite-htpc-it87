# Bazzite HTPC (Steam Gaming Mode) image. Swap for another Gaming Mode
# variant if needed, e.g. ghcr.io/ublue-os/bazzite-deck-nvidia:stable,
# bazzite-deck-gnome:stable or bazzite-deck-nvidia-gnome:stable.
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-deck:stable

# Upstream it87 driver (frankcrawford's rewrite); any branch, tag or commit.
ARG IT87_REPO=https://github.com/frankcrawford/it87
ARG IT87_REF=master

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY certs /certs

### BUILD it87
## Compiled in a throwaway stage on top of the same base image, so it is built
## against the exact kernel-devel shipped with that Bazzite kernel.
FROM ${BASE_IMAGE} AS it87-builder
ARG IT87_REPO
ARG IT87_REF

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=kmod_key \
    IT87_REPO="${IT87_REPO}" IT87_REF="${IT87_REF}" /ctx/build-it87.sh

# Base Image
FROM ${BASE_IMAGE}

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=it87-builder,source=/out,target=/it87 \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
