MAKEFILES_VERSION=6.0.0

.DEFAULT_GOAL:=help
K8S_PRE_GENERATE_TARGETS=
include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include build/make/clean.mk
include build/make/k8s-dogu.mk

.PHONY: build-dogu
build-dogu: image-import install-dogu-descriptor ## Builds a new version of the dogu and deploys it into the K8s-EcoSystem.