TOPDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Default operator for FBC work in this repo
OPERATOR_NAME ?= portworx-certified
OPERATOR_DIR  ?= $(TOPDIR)/operators/$(OPERATOR_NAME)
CATALOGS_DIR  ?= $(TOPDIR)/catalogs
BINDIR        ?= $(TOPDIR)/bin

# Delegate basic FBC catalog operations to the operator's Makefile

.PHONY: catalogs
catalogs:
	@$(MAKE) -C $(OPERATOR_DIR) catalogs

.PHONY: validate-catalogs
validate-catalogs:
	@$(MAKE) -C $(OPERATOR_DIR) validate-catalogs

.PHONY: clean
clean:
	@$(MAKE) -C $(OPERATOR_DIR) clean


# ------------------------
# FBC registry image build
# ------------------------

# Image build args
# Example usage:
#   make fbc-registry OCP_VERSION=v4.16 RELEASE_VER=25.5.1 \
#     DOCKER_HUB_REPO=my-reg.io/ns DOCKER_HUB_REGISTRY_IMG=px-fbc-registry:v4.16-25.5.1

OCP_VERSION         ?= v4.16
RELEASE_VER         ?= dev
DOCKER_HUB_REPO     ?= docker.io/portworx
FBC_REGISTRY_IMG    ?= px-fbc-registry:$(OCP_VERSION)-$(RELEASE_VER)
FBC_REGISTRY_IMG_PREFIX ?= px-fbc-registry

# Full image reference including registry/repo
FBC_REGISTRY_IMG_FULL := $(DOCKER_HUB_REPO)/$(FBC_REGISTRY_IMG)

# Directory containing FBC content for a given OCP version
FBC_CONTENT_DIR := $(CATALOGS_DIR)/$(OCP_VERSION)/$(OPERATOR_NAME)

# Dockerfile used to build the FBC registry image
FBC_DOCKERFILE ?= $(TOPDIR)/Dockerfile.fbc

# Docker/Podman binary (override if needed)
CONTAINER_CMD ?= podman


.PHONY: build-fbc-registry
build-fbc-registry:
	@if [ ! -d "$(FBC_CONTENT_DIR)" ]; then \
			echo "FBC content not found at $(FBC_CONTENT_DIR). Run 'make catalogs' first."; \
			exit 1; \
		fi
	@echo "Building FBC registry image $(FBC_REGISTRY_IMG_FULL) from $(FBC_CONTENT_DIR)"
		@$(CONTAINER_CMD) build \
			-t $(FBC_REGISTRY_IMG_FULL) \
			-f $(FBC_DOCKERFILE) \
			$(FBC_CONTENT_DIR)


.PHONY: push-fbc-registry
push-fbc-registry:
	@echo "Pushing FBC registry image $(FBC_REGISTRY_IMG_FULL)"
	@$(CONTAINER_CMD) push $(FBC_REGISTRY_IMG_FULL)


.PHONY: fbc-registry
fbc-registry:
	@echo "Building and pushing FBC registry image for $(OCP_VERSION) / $(RELEASE_VER)"
	@$(MAKE) build-fbc-registry \
		OCP_VERSION=$(OCP_VERSION) RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(FBC_REGISTRY_IMG)
	@$(MAKE) push-fbc-registry \
		OCP_VERSION=$(OCP_VERSION) RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(FBC_REGISTRY_IMG)


# Build/push for a fixed set of OCP versions (adjust list as needed)
SUPPORTED_OCP_VERSIONS ?= v4.12 v4.13 v4.14 v4.15 v4.16 v4.17 v4.18 v4.19 v4.20

.PHONY: build-all-fbc-registries
build-all-fbc-registries:
	@for ver in $(SUPPORTED_OCP_VERSIONS); do \
			$(MAKE) build-fbc-registry OCP_VERSION=$$ver RELEASE_VER=$(RELEASE_VER) \
				DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(FBC_REGISTRY_IMG_PREFIX):$$ver-$(RELEASE_VER); \
		done

.PHONY: push-all-fbc-registries
push-all-fbc-registries:
	@for ver in $(SUPPORTED_OCP_VERSIONS); do \
			$(MAKE) push-fbc-registry OCP_VERSION=$$ver RELEASE_VER=$(RELEASE_VER) \
				DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(FBC_REGISTRY_IMG_PREFIX):$$ver-$(RELEASE_VER); \
		done

.PHONY: all-fbc-registries
all-fbc-registries:
	@$(MAKE) build-all-fbc-registries RELEASE_VER=$(RELEASE_VER) DOCKER_HUB_REPO=$(DOCKER_HUB_REPO)
	@$(MAKE) push-all-fbc-registries RELEASE_VER=$(RELEASE_VER) DOCKER_HUB_REPO=$(DOCKER_HUB_REPO)
