# syntax=docker/dockerfile:1.7
# longhorn-manager for linux/riscv64. Follows upstream's package/Dockerfile at the same tag:
# the binary is pure Go (CGO_ENABLED=0 in scripts/build), cross-compiled on the build host via
# scripts/build's ARCHS; the runtime is openSUSE Tumbleweed (SLE BCI has no riscv64).
# Also used for the CSI plugin and driver-deployer, which run this image.

FROM --platform=$BUILDPLATFORM golang:1.26-trixie AS builder
ARG TARGETARCH
ARG LONGHORN_TWO_MINOR_UPGRADE_DISTROS
ENV LONGHORN_TWO_MINOR_UPGRADE_DISTROS=${LONGHORN_TWO_MINOR_UPGRADE_DISTROS}
RUN [ "$TARGETARCH" = riscv64 ] || { echo "riscv64 only (upstream images cover $TARGETARCH)"; exit 1; }
RUN git config --global --add safe.directory '*'
WORKDIR /app
COPY . /app
RUN ARCHS=${TARGETARCH} ./scripts/build

FROM registry.opensuse.org/opensuse/tumbleweed:latest AS release
ARG TARGETARCH
RUN zypper -n ref && zypper -n install iputils iproute2 nfs-client cifs-utils bind-utils e2fsprogs xfsprogs \
      zip unzip kmod smartmontools && \
    zypper clean -a
COPY --from=builder /app/bin/longhorn-manager-${TARGETARCH} /usr/local/sbin/longhorn-manager
COPY --from=builder /app/package/launch-manager /app/package/nsmounter /usr/local/sbin/
EXPOSE 9500
CMD ["launch-manager"]
