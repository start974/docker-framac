.PHONY: build manifest buildfat check run debug push save clean clobber

REPO    = start974/
NAME    = framac
TAG     = 33.0
ARCH   := $$(arch=$$(uname -m); if [[ $$arch == "x86_64" ]]; then echo amd64; else echo $$arch; fi)

ARCHS   = amd64 arm64
IMAGES := $(ARCHS:%=$(REPO)$(NAME):$(TAG)-%)
PLATFORMS := $$(first="True"; for a in $(ARCHS); do if [[ $$first == "True" ]]; then printf "linux/%s" $$a; first="False"; else printf ",linux/%s" $$a; fi; done)

help:
	@echo "# Available targets:"
	@echo "#   - build: build docker image"
	@echo "#   - clean: clean docker build cache"
	@echo "#   - run: run docker container, GUIs at http://localhost:6080/vnc.html"
	@echo "#   - push: push docker image to docker hub"

# Build image
build:
	docker build --tag $(REPO)$(NAME):$(TAG)-$(ARCH) .
	@docker image prune --force > /dev/null

# Safe way to build multiarchitecture images:
# - build each image on the matching hardware, with the -$(ARCH) tag
# - push the architecture specific images to Dockerhub
# - build a manifest list referencing those images
# - push the manifest list so that the multiarchitecture image exist
manifest:
	docker manifest create $(REPO)$(NAME):$(TAG) $(IMAGES)
	@for arch in $(ARCHS); \
	 do \
	   echo docker manifest annotate --os linux --arch $$arch $(REPO)$(NAME):$(TAG) $(REPO)$(NAME):$(TAG)-$$arch; \
	   docker manifest annotate --os linux --arch $$arch $(REPO)$(NAME):$(TAG) $(REPO)$(NAME):$(TAG)-$$arch; \
	 done
	docker manifest push $(REPO)$(NAME):$(TAG)

rmmanifest:
	docker manifest rm $(REPO)$(NAME):$(TAG)

# Create new builder supporting multi architecture images
newbuilder:
	docker buildx create --name newbuilder
	docker buildx use newbuilder

# Hasardous way to build multiarchitecture images:
# - use buildx to try to build the different images using qemu for foreign architectures
# This fails with some images because of the emulation of foreign architectures
# --load with multiarch image fails (2021-02-15), use --push instead
buildfat:
	docker buildx build --push \
	  --platform $(PLATFORMS) \
	  --tag $(REPO)$(NAME):$(TAG) .
	@docker image prune --force > /dev/null

push:
	docker push $(REPO)$(NAME):$(TAG)-$(ARCH)

save:
	docker save $(REPO)$(NAME):$(TAG)-$(ARCH) | gzip > $(NAME)-$(TAG)-$(ARCH).tar.gz

# Clear caches
clean:
	docker builder prune

clobber:
	docker rmi $(REPO)$(NAME):$(TAG) $(REPO)$(NAME):$(TAG)-$(ARCH)
	docker builder prune --all

run:
	docker run --rm --tty --interactive \
		--env USERNAME="`id -n -u`" --env USERID="`id -u`" \
		--volume "${PWD}":/workspace:rw \
		--workdir /workspace \
		--name $(NAME) \
		--publish 127.0.0.1:6080:6080 \
		--shm-size 1g \
		$(REPO)$(NAME):$(TAG)-$(ARCH)

runasroot:
	docker run --rm --tty --interactive \
		--volume "${PWD}":/workspace:rw \
		--workdir /workspace \
		--name $(NAME) \
		--publish 127.0.0.1:6080:6080 \
		--shm-size 1g \
		--user 0 \
		$(REPO)$(NAME):$(TAG)-$(ARCH)
