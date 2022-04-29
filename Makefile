MAKEFILES_VERSION=5.0.0

.DEFAULT_GOAL:=help

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include build/make/clean.mk
include build/make/k8s-dogu.mk