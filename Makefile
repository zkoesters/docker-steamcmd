REPO_NAME  ?= zkoesters
IMAGE_NAME ?= steamcmd

DOCKER=docker
GIT=git

OFFIMG_LOCAL_CLONE=$(HOME)/official-images
OFFIMG_REPO_URL=https://github.com/docker-library/official-images.git

VERSIONS = trixie-root trixie trixie-wine-root trixie-wine trixie-proton-root trixie-proton

all: build test

build: $(foreach version,$(VERSIONS),build-$(version))

define build-version
build-$1:
	$(DOCKER) build --target=$(version) --pull -t $(REPO_NAME)/$(IMAGE_NAME):$(version) -f Dockerfile .
	$(DOCKER) images                              $(REPO_NAME)/$(IMAGE_NAME):$(version)
endef
$(foreach version,$(VERSIONS),$(eval $(call build-version,$(version))))

test-prepare:
ifeq ("$(wildcard $(OFFIMG_LOCAL_CLONE))","")
	$(GIT) clone $(OFFIMG_REPO_URL) $(OFFIMG_LOCAL_CLONE)
endif

test: $(foreach version,$(VERSIONS),test-$(version))

define test-version
test-$1: test-prepare build-$1
	$(OFFIMG_LOCAL_CLONE)/test/run.sh -c $(OFFIMG_LOCAL_CLONE)/test/config.sh $(REPO_NAME)/$(IMAGE_NAME):$(version)
endef
$(foreach version,$(VERSIONS),$(eval $(call test-version,$(version))))

.PHONY: build test-prepare test all