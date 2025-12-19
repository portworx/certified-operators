# This Makefile provides a set of targets to generate and validate operator catalogs
# using the Operator Package Manager (opm) tool.

# The makefile should be placed in the root of the operator repository.
# for example at: <operator-repo>/operators/<operator-name>/Makefile

PWD=$(shell pwd)
OPERATOR_NAME=$(shell basename $(PWD))
TOPDIR=$(abspath $(dir $(PWD))/../)
BINDIR=${TOPDIR}/bin

# Add the bin directory to the PATH
export PATH := $(BINDIR):$(PATH)
# A place to store the generated catalogs
CATALOG_DIR=${TOPDIR}/catalogs

# The operator pipeline image to use for the fbc-onboarding target
OPERATOR_PIPELINE_IMAGE ?= quay.io/redhat-isv/operator-pipelines-images:released

# Define the paths for both auth files
DOCKER_CONFIG := $(HOME)/.docker/config.json
CONTAINERS_AUTH := $(XDG_RUNTIME_DIR)/containers/auth.json


.PHONY: fbc-onboarding
fbc-onboarding: clean
	@if [ -f $(DOCKER_CONFIG) ]; then \
		echo "Using Docker config file: $(DOCKER_CONFIG)"; \
		CONFIG_VOLUME="-v $(DOCKER_CONFIG):/root/.docker/config.json"; \
	elif [ -f $(CONTAINERS_AUTH) ]; then \
		echo "Using containers auth file: $(CONTAINERS_AUTH)"; \
		CONFIG_VOLUME="-v $(CONTAINERS_AUTH):/root/.docker/config.json"; \
	else \
		echo "No authentication file found."; \
	fi; \
	podman run \
		--rm \
		--user $(id -u):$(id -g) \
		--security-opt label=disable \
		--pull always \
		-v $(TOPDIR):/workspace \
		$$CONFIG_VOLUME \
		$(OPERATOR_PIPELINE_IMAGE) fbc-onboarding \
			--repo-root /workspace \
			--operator-name $(OPERATOR_NAME) \
			--cache-dir /workspace/.catalog_cache

.PHONY: catalogs

# Catalogs are generated based on the mapping in ci.yaml file
# The example of the mapping is:
# fbc:
#   enabled: true
#   catalog_mapping:
#     - template_name: basic.yaml
#       catalog_names: ["v4.14", "v4.15", "v4.16"]
#       type: olm.template.basic
#     - template_name: semver.yaml
#       catalog_names: ["v4.13", "v4.17"]
#       type: olm.semver
catalogs: render_catalogs.sh ${BINDIR}/opm ${BINDIR}/yq clean
	@echo "Rendering catalogs from templates"
	@${BINDIR}/render_catalogs.sh


# validate-catalogs target illustrates FBC validation
# all FBC must pass opm validation in order to be able to be used in a catalog
.PHONY: validate-catalogs
validate-catalogs: ${BINDIR}/opm
	@find ${TOPDIR}/catalogs -type d -name ${OPERATOR_NAME} -exec \
		sh -c '${BINDIR}/opm validate $$(dirname "{}") && echo "✅ Catalog validation passed: {}" || echo "❌ Catalog validation failed: {}"' \;

.PHONY: create-catalog-dir
create-catalog-dir:
	@mkdir -p $(CATALOG_DIR)

.PHONY: clean
clean: create-catalog-dir
	@echo "Cleaning up the operator catalogs from $(CATALOG_DIR)"
	@find $(CATALOG_DIR) -type d -name ${OPERATOR_NAME} -exec rm -rf {} +


OS=$(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(shell uname -m | sed 's/x86_64/amd64/')

# Automatically download the binaries and scripts and place them in the bin directory
OPM_VERSION ?= v1.46.0
${BINDIR}/opm:
	if [ ! -d  ${BINDIR} ]; then mkdir -p ${BINDIR}; fi
	curl -sLO https://github.com/operator-framework/operator-registry/releases/download/$(OPM_VERSION)/$(OS)-$(ARCH)-opm && chmod +x $(OS)-$(ARCH)-opm && mv $(OS)-$(ARCH)-opm ${BINDIR}/opm

YQ_VERSION ?= v4.45.1
${BINDIR}/yq:
	if [ ! -d ${BINDIR} ]; then mkdir -p ${BINDIR}; fi
	curl -sLO https://github.com/mikefarah/yq/releases/download/$(YQ_VERSION)/yq_$(OS)_$(ARCH) && mv yq_$(OS)_$(ARCH) ${BINDIR}/yq && chmod +x ${BINDIR}/yq

.PHONY: render_catalogs.sh
render_catalogs.sh:
	if [ ! -d ${BINDIR} ]; then mkdir -p ${BINDIR}; fi
	curl -sLO https://raw.githubusercontent.com/redhat-openshift-ecosystem/operator-pipelines/main/fbc/render_catalogs.sh
	mv render_catalogs.sh ${BINDIR}/render_catalogs.sh
	chmod +x ${BINDIR}/render_catalogs.sh

# Optional FBC registry image helper targets.
# These wrap lower-level FBC make targets that are expected to exist in $(FBC_DIR).
#
# Variables expected to be provided by the caller:
#   - FBC_DIR                : directory that contains the FBC Makefile (defaults to $(TOPDIR))
#   - OCP_VERSION            : catalog version to build (e.g. v4.18)
#   - RELEASE_VER            : logical release version (e.g. 25.5.1)
#   - DOCKER_HUB_REPO        : base Docker Hub repo (e.g. docker.io/portworx)
#   - DOCKER_HUB_REGISTRY_IMG: full image name:tag for the FBC registry image

FBC_DIR ?= $(TOPDIR)

.PHONY: fbc-build-registry
fbc-build-registry:
	@echo "Building FBC registry image..."
	@$(MAKE) -C $(FBC_DIR) build-fbc-registry OCP_VERSION=$(OCP_VERSION) RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(DOCKER_HUB_REGISTRY_IMG)

.PHONY: fbc-push-registry
fbc-push-registry:
	@echo "Pushing FBC registry image..."
	@$(MAKE) -C $(FBC_DIR) push-fbc-registry OCP_VERSION=$(OCP_VERSION) RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(DOCKER_HUB_REGISTRY_IMG)

.PHONY: fbc-registry
fbc-registry:
	@echo "Building and pushing FBC registry image..."
	@$(MAKE) -C $(FBC_DIR) fbc-registry OCP_VERSION=$(OCP_VERSION) RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(DOCKER_HUB_REGISTRY_IMG)

.PHONY: fbc-build-all-registries
fbc-build-all-registries:
	@echo "Building all FBC registry images..."
	@$(MAKE) -C $(FBC_DIR) build-all-fbc-registries RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(DOCKER_HUB_REGISTRY_IMG)

.PHONY: fbc-push-all-registries
fbc-push-all-registries:
	@echo "Pushing all FBC registry images..."
	@$(MAKE) -C $(FBC_DIR) push-all-fbc-registries RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(DOCKER_HUB_REGISTRY_IMG)

.PHONY: fbc-all-registries
fbc-all-registries:
	@echo "Building and pushing all FBC registry images..."
	@$(MAKE) -C $(FBC_DIR) all-fbc-registries RELEASE_VER=$(RELEASE_VER) \
		DOCKER_HUB_REPO=$(DOCKER_HUB_REPO) FBC_REGISTRY_IMG=$(DOCKER_HUB_REGISTRY_IMG)

.PHONY: fbc-test
fbc-test:
	@echo "Building and pushing test registry image for v4.16..."
	@if [ ! -d "$(FBC_DIR)/catalogs/v4.16/$(OPERATOR_NAME)" ]; then \
			echo "Catalogs not found, generating them first..."; \
			$(MAKE) catalogs; \
		else \
			echo "Using existing catalogs (run 'make clean' to regenerate)"; \
		fi
	@$(MAKE) fbc-registry OCP_VERSION=v4.16 RELEASE_VER=$(RELEASE_VER)

.PHONY: fbc-prod
fbc-prod:
	@echo "Building and pushing all registry images for production..."
	@if [ ! -d "$(FBC_DIR)/catalogs/v4.16/$(OPERATOR_NAME)" ]; then \
			echo "Catalogs not found, generating them first..."; \
			$(MAKE) catalogs; \
		else \
			echo "Using existing catalogs (run 'make clean' to regenerate)"; \
		fi
	@$(MAKE) fbc-all-registries RELEASE_VER=$(RELEASE_VER)

.PHONY: fbc-build-test
fbc-build-test:
	@echo "Building test registry image for v4.16 (no push)..."
	@if [ ! -d "$(FBC_DIR)/catalogs/v4.16/$(OPERATOR_NAME)" ]; then \
			echo "Catalogs not found, generating them first..."; \
			$(MAKE) catalogs; \
		else \
			echo "Using existing catalogs (run 'make clean' to regenerate)"; \
		fi
	@$(MAKE) fbc-build-registry OCP_VERSION=v4.16 RELEASE_VER=$(RELEASE_VER)

.PHONY: fbc-build-prod
fbc-build-prod:
	@echo "Building all registry images for production (no push)..."
	@if [ ! -d "$(FBC_DIR)/catalogs/v4.16/$(OPERATOR_NAME)" ]; then \
			echo "Catalogs not found, generating them first..."; \
			$(MAKE) catalogs; \
		else \
			echo "Using existing catalogs (run 'make clean' to regenerate)"; \
		fi
	@$(MAKE) fbc-build-all-registries RELEASE_VER=$(RELEASE_VER)
