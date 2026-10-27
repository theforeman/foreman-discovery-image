# Build with rootless Podman; see README.md. The result is a bootable OS
# container, consumed by image-builder's pxe-tar-xz output type.
ARG BASE_IMAGE=quay.io/centos-bootc/centos-bootc:stream10
FROM ${BASE_IMAGE}

ARG FOREMAN_VERSION=nightly
ARG EXTRA_PACKAGES=

# Keep application packages separate from the image configuration so edits to
# root/ do not repeat the RPM transaction. Nightly and plugin RPMs are unsigned.
# Copy shell scripts for compatibility with Ubuntu 24.04 Podman's parser.
COPY bootc/packages.txt /tmp/fdi-packages.txt
COPY bootc/install-packages.sh /tmp/fdi-install-packages.sh
RUN /bin/bash /tmp/fdi-install-packages.sh

COPY root/ /
COPY bootc/root/ /

ARG FDI_VERSION=dev
ARG FDI_RELEASE=1
ARG FDI_ROOT_PASSWORD_HASH=
ARG FDI_SSH=0
ARG FDI_SELINUX=permissive
ARG EXTRA_DRIVERS=

COPY bootc/configure.sh /tmp/fdi-configure.sh
RUN /bin/bash /tmp/fdi-configure.sh

LABEL org.opencontainers.image.title="Foreman Discovery Image" \
      org.opencontainers.image.version="${FDI_VERSION}" \
      org.opencontainers.image.source="https://github.com/theforeman/foreman-discovery-image"
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/bin/discovery-container-entrypoint"]
CMD ["/sbin/init"]
