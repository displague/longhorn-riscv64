# syntax=docker/dockerfile:1.7
# csi-node-driver-registrar for linux/riscv64, from kubernetes-csi/node-driver-registrar at the tag Longhorn ships (longhornio/csi-node-driver-registrar).
# Same build as upstream's release-tools (make build-csi-node-driver-registrar), cross-compiled for riscv64;
# same distroless base as upstream, in its Debian 13 flavour (the only one with riscv64).
FROM --platform=$BUILDPLATFORM golang:1.26-trixie AS build
ARG TARGETARCH
RUN [ "$TARGETARCH" = riscv64 ] || { echo "riscv64 only (upstream images cover $TARGETARCH)"; exit 1; }
RUN git config --global --add safe.directory '*'
WORKDIR /src
COPY . .
RUN make build-csi-node-driver-registrar BUILD_PLATFORMS="linux riscv64"

FROM gcr.io/distroless/static-debian13:latest
COPY --from=build /src/bin/csi-node-driver-registrar /csi-node-driver-registrar
ENTRYPOINT ["/csi-node-driver-registrar"]
