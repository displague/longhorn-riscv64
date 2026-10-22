# syntax=docker/dockerfile:1.7
# longhorn-engine for linux/riscv64. Follows upstream's Dockerfile (binaries) and
# package/Dockerfile (runtime) at the same tag, with three changes:
#  - Go is cross-compiled on the build host (cgo: pkg/qcow links a riscv64 libqcow built here)
#  - the runtime is openSUSE Tumbleweed: SLE BCI has no riscv64, Tumbleweed has the same zypper names
#  - /tini is openSUSE's catatonit (tini publishes no riscv64 binary)
# Build contexts: . = build/longhorn-engine, deps = build/dep-versions, im = build/longhorn-instance-manager
# (upstream bundles an instance-manager binary built from its master branch; we use the same release).

ARG GRPC_HEALTH_PROBE_VERSION=v0.4.60

FROM --platform=$BUILDPLATFORM golang:1.26-trixie AS gobuild
ARG TARGETARCH
RUN [ "$TARGETARCH" = riscv64 ] || { echo "riscv64 only (upstream images cover $TARGETARCH)"; exit 1; }
RUN dpkg --add-architecture riscv64 && apt-get update && apt-get install -y --no-install-recommends \
      gcc-riscv64-linux-gnu libc6-dev-riscv64-cross zlib1g-dev:riscv64 \
      autoconf automake autopoint gettext libtool pkg-config jq && \
    rm -rf /var/lib/apt/lists/*
COPY --from=deps . /usr/src/dep-versions
# libqcow, static, into the cross sysroot (upstream: dep-versions/scripts/build-libqcow.sh)
RUN v=/usr/src/dep-versions/versions.json && \
    git clone "$(jq -r .libqcow.repo $v)" /usr/src/libqcow && cd /usr/src/libqcow && \
    git checkout "$(jq -r .libqcow.commit $v)" && autoreconf -i && \
    PKG_CONFIG_PATH=/usr/lib/riscv64-linux-gnu/pkgconfig ./configure --host=riscv64-linux-gnu \
      --prefix=/usr/riscv64-linux-gnu --enable-static --disable-shared && \
    make -j"$(nproc)" && make install
ENV CGO_ENABLED=1 GOOS=linux GOARCH=riscv64 CC=riscv64-linux-gnu-gcc GOFLAGS=-mod=vendor \
    CGO_LDFLAGS=-L/usr/lib/riscv64-linux-gnu
RUN git config --global --add safe.directory '*'
COPY --from=im . /go/src/github.com/longhorn/longhorn-instance-manager
RUN cd /go/src/github.com/longhorn/longhorn-instance-manager && \
    go build -o /usr/local/bin/longhorn-instance-manager -tags netgo -ldflags "-linkmode external -extldflags -static"
WORKDIR /go/src/github.com/longhorn/longhorn-engine
COPY . .
RUN ./scripts/build

# tgt + liblonghorn: small C builds, run in the target arch (QEMU under buildx)
FROM registry.opensuse.org/opensuse/tumbleweed:latest AS cbuild
RUN zypper -n ref && zypper -n install cmake curl git gcc make wget xsltproc docbook-xsl-stylesheets jq tar gzip && \
    zypper clean -a
COPY --from=deps . /usr/src/dep-versions
RUN bash /usr/src/dep-versions/scripts/build-liblonghorn.sh "" "" && \
    bash /usr/src/dep-versions/scripts/build-tgt.sh "" ""

FROM registry.opensuse.org/opensuse/tumbleweed:latest AS release
ARG GRPC_HEALTH_PROBE_VERSION
RUN zypper -n ref && zypper -n install nfs-client nfs4-acl-tools cifs-utils libaio1 sg3_utils \
      iputils iproute2 qemu-tools e2fsprogs jq catatonit && \
    zypper clean -a && ln -s /usr/bin/catatonit /tini
COPY --from=cbuild /usr/sbin/tgt-admin /usr/sbin/tgt-setup-lun /usr/sbin/tgtadm /usr/sbin/tgtd /usr/sbin/tgtimg \
     /usr/local/bin/
ADD --chmod=755 https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-riscv64 \
    /usr/local/bin/grpc_health_probe
COPY --from=gobuild /go/src/github.com/longhorn/longhorn-engine/bin/longhorn \
     /go/src/github.com/longhorn/longhorn-engine/bin/longhorn-instance-manager /usr/local/bin/
COPY package/launch-simple-longhorn package/engine-manager package/launch-simple-file /usr/local/bin/
RUN ldd /usr/local/bin/tgtd | grep "not found" && exit 1 || true
ENTRYPOINT ["/tini", "--"]
CMD ["longhorn"]
