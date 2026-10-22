# syntax=docker/dockerfile:1.7
# longhorn-share-manager for linux/riscv64 (RWX volumes). Follows upstream's package/Dockerfile at the
# same tag: Go cross-compiled on the build host via scripts/build's ARCHS; nfs-ganesha built in the
# target arch (QEMU under buildx) with dep-versions' own script; runtime on openSUSE Tumbleweed, whose
# main repo has everything upstream pulls from extra OBS repos for SLE (gcc14, cmake, the -devel libs).
# Longhorn also needs this image on every node: longhorn-manager's pod pre-pulls it.
# Build contexts: . = build/longhorn-share-manager, deps = build/dep-versions

FROM --platform=$BUILDPLATFORM golang:1.26-trixie AS app_builder
ARG TARGETARCH
RUN [ "$TARGETARCH" = riscv64 ] || { echo "riscv64 only (upstream images cover $TARGETARCH)"; exit 1; }
RUN git config --global --add safe.directory '*'
WORKDIR /app
COPY . /app
RUN ARCHS=${TARGETARCH} ./scripts/build

FROM registry.opensuse.org/opensuse/tumbleweed:latest AS lib_builder
RUN zypper -n ref && zypper -n install autoconf bison curl git tar gzip jq libcurl-devel json-c-devel \
      libacl-devel lsb-release libdbus-1-3 liburcu-devel libblkid-devel e2fsprogs e2fsprogs-devel \
      xfsprogs xfsprogs-devel dbus-1-devel flex Mesa-libGL-devel nfsidmap-devel graphviz-devel doxygen \
      libnsl-devel cmake make gcc14 gcc14-c++ && \
    zypper clean -a
COPY --from=deps . /usr/src/dep-versions
RUN bash /usr/src/dep-versions/scripts/build-nfs-ganesha.sh "" ""

FROM registry.opensuse.org/opensuse/tumbleweed:latest AS release
ARG TARGETARCH
RUN zypper -n ref && zypper -n install rpcbind hostname libblkid1 'libjson-c*' dbus-1 \
      nfsidmap-devel libnsl-devel nfs-kernel-server xfsprogs e2fsprogs nfs-client nfs4-acl-tools && \
    zypper clean -a
RUN mkdir -p /var/run/dbus && mkdir -p /export
RUN echo /usr/local/lib64 > /etc/ld.so.conf.d/local_libs.conf
RUN [ -f /etc/nsswitch.conf ] && sed -i 's/systemd//g' /etc/nsswitch.conf || true
RUN ln -sf /proc/self/mounts /etc/mtab
COPY --from=lib_builder /usr/local /usr/local/
COPY --from=lib_builder /ganesha-extra /
COPY --from=app_builder /app/bin/longhorn-share-manager-${TARGETARCH} /longhorn-share-manager
RUN ldconfig && ldd /usr/local/bin/ganesha.nfsd | grep "not found" && exit 1 || true
EXPOSE 2049/tcp
ENTRYPOINT ["/longhorn-share-manager"]
