# syntax=docker/dockerfile:1.7
# longhorn-instance-manager for linux/riscv64. Follows upstream's Dockerfile (binary) and
# package/Dockerfile (runtime) at the same tag. Changes, beyond those noted in the engine's Dockerfile:
#  - no SPDK, json-c or source-built nvme-cli: those exist only for the v2 (SPDK) data engine, which
#    stays off on riscv64. The v1 engine (tgt + liblonghorn) is complete; package/instance-manager
#    starts SPDK only with --enable-spdk. nvme-cli comes from the distro instead.
#  - go-spdk-helper is still built (pure Go) so the image has every binary upstream's has but SPDK's.
# Build contexts: . = build/longhorn-instance-manager, deps = build/dep-versions

ARG GRPC_HEALTH_PROBE_VERSION=v0.4.60

FROM --platform=$BUILDPLATFORM golang:1.26-trixie AS gobuild
ARG TARGETARCH
RUN [ "$TARGETARCH" = riscv64 ] || { echo "riscv64 only (upstream images cover $TARGETARCH)"; exit 1; }
RUN dpkg --add-architecture riscv64 && apt-get update && apt-get install -y --no-install-recommends \
      gcc-riscv64-linux-gnu libc6-dev-riscv64-cross zlib1g-dev:riscv64 \
      autoconf automake autopoint gettext libtool pkg-config jq && \
    rm -rf /var/lib/apt/lists/*
COPY --from=deps . /usr/src/dep-versions
RUN v=/usr/src/dep-versions/versions.json && \
    git clone "$(jq -r .libqcow.repo $v)" /usr/src/libqcow && cd /usr/src/libqcow && \
    git checkout "$(jq -r .libqcow.commit $v)" && autoreconf -i && \
    PKG_CONFIG_PATH=/usr/lib/riscv64-linux-gnu/pkgconfig ./configure --host=riscv64-linux-gnu \
      --prefix=/usr/riscv64-linux-gnu --enable-static --disable-shared && \
    make -j"$(nproc)" && make install
RUN git config --global --add safe.directory '*'
RUN v=/usr/src/dep-versions/versions.json && \
    git clone "$(jq -r '.["go-spdk-helper"].repo' $v)" /usr/src/go-spdk-helper && cd /usr/src/go-spdk-helper && \
    git checkout "$(jq -r '.["go-spdk-helper"].commit' $v)" && \
    CGO_ENABLED=0 GOOS=linux GOARCH=riscv64 go build -o /usr/local/bin/go-spdk-helper
ENV CGO_ENABLED=1 GOOS=linux GOARCH=riscv64 CC=riscv64-linux-gnu-gcc GOFLAGS=-mod=vendor \
    CGO_LDFLAGS=-L/usr/lib/riscv64-linux-gnu
WORKDIR /go/src/github.com/longhorn/longhorn-instance-manager
COPY . .
RUN ./scripts/build

FROM registry.opensuse.org/opensuse/tumbleweed:latest AS cbuild
RUN zypper -n ref && zypper -n install cmake curl git gcc make wget xsltproc docbook-xsl-stylesheets jq tar gzip && \
    zypper clean -a
COPY --from=deps . /usr/src/dep-versions
RUN bash /usr/src/dep-versions/scripts/build-liblonghorn.sh "" "" && \
    bash /usr/src/dep-versions/scripts/build-tgt.sh "" ""

FROM registry.opensuse.org/opensuse/tumbleweed:latest AS release
ARG GRPC_HEALTH_PROBE_VERSION
RUN zypper -n ref && zypper -n install kmod jq util-linux procps gawk qemu-tools e2fsprogs xfsprogs \
      python3-base device-mapper netcat-openbsd fuse3 logrotate cifs-utils sg3_utils iproute2 \
      util-linux-systemd nfs-client nfs4-acl-tools nvme-cli catatonit && \
    zypper clean -a && ln -s /usr/bin/catatonit /tini
ADD --chmod=755 https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-riscv64 \
    /usr/local/bin/grpc_health_probe
COPY --from=gobuild /usr/local/bin/go-spdk-helper /usr/local/bin/
COPY --from=cbuild /usr/sbin/tgt-admin /usr/sbin/tgt-setup-lun /usr/sbin/tgtadm /usr/sbin/tgtd /usr/sbin/tgtimg \
     /usr/sbin/
COPY --from=gobuild /go/src/github.com/longhorn/longhorn-instance-manager/bin/longhorn-instance-manager /usr/local/bin/
COPY package/instance-manager package/instance-manager-v2-prestop package/exec-logrotate package/start-spdk-tgt \
     /usr/local/bin/
RUN ldd /usr/local/bin/* /usr/sbin/tgt* 2>/dev/null | grep "not found" && exit 1 || true
ENTRYPOINT ["/tini", "--"]
CMD ["longhorn"]
