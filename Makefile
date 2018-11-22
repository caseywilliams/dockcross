
#
# Parameters
#

# Name of the docker executable
DOCKER = docker

# Docker organization to pull the images from
ORG = dockcross

# Directory where to generate the dockcross script for each images (e.g bin/dockcross-manylinux-x64)
BIN = ./bin

# These images are built using the "build implicit rule"
STANDARD_IMAGES = linux-s390x android-arm android-arm64 linux-x86 linux-x64 linux-arm64 linux-armv5 linux-armv6 linux-armv7 linux-mips linux-mipsel linux-ppc64le windows-x86 windows-x64 windows-x64-posix

# Generated Dockerfiles.
GEN_IMAGES = linux-s390x linux-mips manylinux-x86 manylinux-x64 browser-asmjs linux-arm64 windows-x86 windows-x64 windows-x64-posix linux-armv7 linux-armv5
GEN_IMAGE_DOCKERFILES = $(addsuffix /Dockerfile,$(GEN_IMAGES))

# These images are expected to have explicit rules for *both* build and testing
NON_STANDARD_IMAGES = browser-asmjs manylinux-x64 manylinux-x86

DOCKER_COMPOSITE_SOURCES = common.docker common.debian common.el common.manylinux common.crosstool common.windows

# This list all available images
IMAGES = $(STANDARD_IMAGES) $(NON_STANDARD_IMAGES)

# Optional arguments for test runner (test/run.py) associated with "testing implicit rule"
linux-ppc64le.test_ARGS = --languages C
windows-x86.test_ARGS = --exe-suffix ".exe"
windows-x64.test_ARGS = --exe-suffix ".exe"
windows-x64-posix.test_ARGS = --exe-suffix ".exe"

# On CircleCI, do not attempt to delete container
# See https://circleci.com/docs/docker-btrfs-error/
RM = --rm
ifeq ("$(CIRCLECI)", "true")
	RM =
endif

# Default Debian jessie base Dockerfile
BASE_DOCKERFILE = Dockerfile
ifeq ("$(BASE)", "centos7")
	BASE_DOCKERFILE = centos7-base/Dockerfile
	# Also append to the $ORG, so that all of the the centos images have a
	# different name from the default image, whatever the org is:
	ORG := $(ORG)-centos7
	# Dockerfiles in subdirectories need this information to adjust for the base:
	#   - ORG is used to construct the name of the final image ($ORG/template-name)
	#   - BASE_IMAGE is used ony to set the FROM value; Default is dockcross/base
	#   - CROSS_TRIPLE differs between base images, too
	BASE_IMAGE_BUILD_ARGS = --build-arg ORG=$(ORG) \
							--build-arg BASE_IMAGE=$(ORG)/base:latest \
							--build-arg CROSS_TRIPLE=x86_64-redhat-linux
endif
# This is used in the subdirectories' Dockerfiles to select the base image

#
# images: This target builds all IMAGES (because it is the first one, it is built by default)
#
images: base $(IMAGES)

#
# test: This target ensures all IMAGES are built and run the associated tests
#
test: base.test $(addsuffix .test,$(IMAGES))

#
# Generic Targets (can specialize later).
#

$(GEN_IMAGE_DOCKERFILES) Dockerfile: %Dockerfile: %Dockerfile.in $(DOCKER_COMPOSITE_SOURCES)
	sed \
		-e '/common.docker/ r common.docker' \
		-e '/common.debian/ r common.debian' \
		-e '/common.el/ r common.el' \
		-e '/common.manylinux/ r common.manylinux' \
		-e '/common.crosstool/ r common.crosstool' \
		-e '/common.windows/ r common.windows' \
		$< > $@

#
# browser-asmjs
#
browser-asmjs: browser-asmjs/Dockerfile
	mkdir -p $@/imagefiles && cp -r imagefiles $@/
	cp -r test browser-asmjs/
	$(DOCKER) build -t $(ORG)/browser-asmjs:latest \
		--build-arg IMAGE=$(ORG)/browser-asmjs \
		--build-arg VCS_REF=`git rev-parse --short HEAD` \
		--build-arg VCS_URL=`git config --get remote.origin.url` \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		browser-asmjs
	rm -rf browser-asmjs/test
	rm -rf $@/imagefiles

browser-asmjs.test: browser-asmjs
	cp -r test browser-asmjs/
	$(DOCKER) run $(RM) dockcross/browser-asmjs > $(BIN)/dockcross-browser-asmjs && chmod +x $(BIN)/dockcross-browser-asmjs
	$(BIN)/dockcross-browser-asmjs python test/run.py --exe-suffix ".js"
	rm -rf browser-asmjs/test

#
# manylinux-x64

manylinux-x64: manylinux-x64/Dockerfile
	mkdir -p $@/imagefiles && cp -r imagefiles $@/
	$(DOCKER) build -t $(ORG)/manylinux-x64:latest \
		--build-arg IMAGE=$(ORG)/manylinux-x64 \
		--build-arg VCS_REF=`git rev-parse --short HEAD` \
		--build-arg VCS_URL=`git config --get remote.origin.url` \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		-f manylinux-x64/Dockerfile .
	rm -rf $@/imagefiles

manylinux-x64.test: manylinux-x64
	$(DOCKER) run $(RM) dockcross/manylinux-x64 > $(BIN)/dockcross-manylinux-x64 && chmod +x $(BIN)/dockcross-manylinux-x64
	$(BIN)/dockcross-manylinux-x64 /opt/python/cp35-cp35m/bin/python test/run.py

#
# manylinux-x86
#

manylinux-x86: manylinux-x86/Dockerfile
	mkdir -p $@/imagefiles && cp -r imagefiles $@/
	$(DOCKER) build -t $(ORG)/manylinux-x86:latest \
		--build-arg IMAGE=$(ORG)/manylinux-x86 \
		--build-arg VCS_REF=`git rev-parse --short HEAD` \
		--build-arg VCS_URL=`git config --get remote.origin.url` \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		-f manylinux-x86/Dockerfile .
	rm -rf $@/imagefiles

manylinux-x86.test: manylinux-x86
	$(DOCKER) run $(RM) dockcross/manylinux-x86 > $(BIN)/dockcross-manylinux-x86 && chmod +x $(BIN)/dockcross-manylinux-x86
	$(BIN)/dockcross-manylinux-x86 /opt/python/cp35-cp35m/bin/python test/run.py

#
# base
#

base: Dockerfile imagefiles/
	$(DOCKER) build -t $(ORG)/base:latest \
		--build-arg IMAGE=$(ORG)/base \
		--build-arg VCS_URL=`git config --get remote.origin.url` \
		--build-arg ORG=$(ORG) \
		--file $(BASE_DOCKERFILE) \
		.

base.test: base
	$(DOCKER) run $(RM) dockcross/base > $(BIN)/dockcross-base && chmod +x $(BIN)/dockcross-base

#
# display
#
display_images:
	for image in $(IMAGES); do echo $$image; done

$(VERBOSE).SILENT: display_images

#
# build implicit rule
#

$(STANDARD_IMAGES): %: %/Dockerfile base
	mkdir -p $@/imagefiles && cp -r imagefiles $@/
	$(DOCKER) build -t $(ORG)/$@:latest \
		--build-arg IMAGE=$(ORG)/$@ \
		--build-arg VCS_REF=`git rev-parse --short HEAD` \
		--build-arg VCS_URL=`git config --get remote.origin.url` \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		$(BASE_IMAGE_BUILD_ARGS) \
		$@
	rm -rf $@/imagefiles

#
# testing implicit rule
#
.SECONDEXPANSION:
$(addsuffix .test,$(STANDARD_IMAGES)): $$(basename $$@)
	$(DOCKER) run $(RM) $(ORG)/$(basename $@) > $(BIN)/$(ORG)-$(basename $@) && chmod +x $(BIN)/$(ORG)-$(basename $@)
	$(BIN)/$(ORG)-$(basename $@) python test/run.py $($@_ARGS)

#
# testing prerequisites implicit rule
#
test.prerequisites:
	mkdir -p $(BIN)

$(addsuffix .test,base $(IMAGES)): test.prerequisites

.PHONY: base images $(IMAGES) test %.test
