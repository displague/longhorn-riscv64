# Longhorn for riscv64: build riscv64 images from the upstream submodules, then publish one tag per
# image whose manifest list holds upstream's own amd64/arm64 images (by digest, untouched) plus ours.
# The cluster keeps a single Longhorn install; each node pulls its own architecture.
#
#   make                      # build every image for riscv64 into out/<image>.tar (no push)
#   make build-longhorn-engine
#   make push-longhorn-engine # build + push <REGISTRY>/<image>:<tag>-riscv64
#   make manifest-longhorn-engine  # <REGISTRY>/<image>:<tag> = upstream amd64/arm64 + ours
#   make release              # push + manifest for every image
#   make tags                 # image -> upstream tag table

REGISTRY          ?= ghcr.io/displague/longhorn-riscv64
UPSTREAM_REGISTRY ?= docker.io/longhornio
PLATFORM          ?= linux/riscv64
BUILDER           ?=
SOURCE            ?= https://github.com/displague/longhorn-riscv64
BUILDX             = docker buildx build $(if $(BUILDER),--builder $(BUILDER)) --platform $(PLATFORM) --progress plain \
                     --label org.opencontainers.image.source=$(SOURCE)
CACHE             ?=

# image -> submodule under upstream/ (the image name is what Longhorn's chart uses)
SRC_longhorn-manager           := longhorn-manager
SRC_longhorn-engine            := longhorn-engine
SRC_longhorn-instance-manager  := longhorn-instance-manager
SRC_csi-attacher               := external-attacher
SRC_csi-provisioner            := external-provisioner
SRC_csi-resizer                := external-resizer
SRC_csi-snapshotter            := external-snapshotter
SRC_csi-node-driver-registrar  := node-driver-registrar
SRC_livenessprobe              := livenessprobe

# extra build contexts per image
CTX_longhorn-engine            := deps=build/dep-versions im=build/longhorn-instance-manager
CTX_longhorn-instance-manager  := deps=build/dep-versions
DEPS_longhorn-engine           := dep-versions longhorn-instance-manager
DEPS_longhorn-instance-manager := dep-versions

IMAGES := longhorn-manager longhorn-engine longhorn-instance-manager \
          csi-attacher csi-provisioner csi-resizer csi-snapshotter csi-node-driver-registrar livenessprobe

# the image's tag = the submodule's exact upstream tag; a submodule off a tag is an error
tag = $(or $(shell git -C upstream/$(SRC_$(1)) describe --tags --exact-match 2>/dev/null),$(error upstream/$(SRC_$(1)) is not on a tag))

.PHONY: all release tags $(addprefix build-,$(IMAGES)) $(addprefix push-,$(IMAGES)) $(addprefix manifest-,$(IMAGES))
all: $(addprefix build-,$(IMAGES))
release: $(addprefix manifest-,$(IMAGES))

tags:
	@$(foreach i,$(IMAGES),printf '%-28s %-24s %s\n' $(i) $(call tag,$(i)) upstream/$(SRC_$(i));)

prepare-%:
	@scripts/prepare $(SRC_$*) $(foreach d,$(DEPS_$*),&& scripts/prepare $(d))

build-%: prepare-%
	@mkdir -p out
	$(BUILDX) -f docker/$*/Dockerfile $(foreach c,$(CTX_$*),--build-context $(c)) $(CACHE) \
	  --output type=oci,dest=out/$*.tar build/$(SRC_$*)

push-%: prepare-%
	$(BUILDX) -f docker/$*/Dockerfile $(foreach c,$(CTX_$*),--build-context $(c)) $(CACHE) \
	  --tag $(REGISTRY)/$*:$(call tag,$*)-riscv64 --push build/$(SRC_$*)

manifest-%: push-%
	scripts/merge-manifest $(UPSTREAM_REGISTRY)/$*:$(call tag,$*) $(REGISTRY)/$*:$(call tag,$*)-riscv64 \
	  $(REGISTRY)/$*:$(call tag,$*)
