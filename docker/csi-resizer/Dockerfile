# syntax=docker/dockerfile:1.7
# csi-resizer for linux/riscv64, from kubernetes-csi/external-resizer at the tag Longhorn ships (longhornio/csi-resizer).
# Same build as upstream's release-tools (make build-csi-resizer), cross-compiled for riscv64;
# same distroless base as upstream, in its Debian 13 flavour (the only one with riscv64).
FROM --platform=$BUILDPLATFORM golang:1.26-trixie AS build
ARG TARGETARCH
RUN [ "$TARGETARCH" = riscv64 ] || { echo "riscv64 only (upstream images cover $TARGETARCH)"; exit 1; }
RUN git config --global --add safe.directory '*'
WORKDIR /src
COPY . .
RUN make build-csi-resizer BUILD_PLATFORMS="linux riscv64"

FROM gcr.io/distroless/static-debian13:latest
COPY --from=build /src/bin/csi-resizer /csi-resizer
ENTRYPOINT ["/csi-resizer"]
