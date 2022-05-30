MAKEFILES_VERSION=6.0.1
ARTIFACT_ID=nginx-ingress

.DEFAULT_GOAL:=help
K8S_PRE_GENERATE_TARGETS=
include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include build/make/clean.mk
include build/make/k8s-dogu.mk

.PHONY: build-dogu
build-dogu: ${TARGET_DIR} image-import install-dogu-descriptor dogu-resource ## Builds a new version of the dogu and deploys it into the K8s-EcoSystem.
	@kubectl apply ${K8S_RESOURCE_TEMP_YAML}

.PHONY: dogu-resource
dogu-resource: ${K8S_RESOURCE_TEMP_YAML}

${K8S_RESOURCE_TEMP_YAML}: ${TARGET_DIR} ${K8S_RESOURCE_TEMP_FOLDER}
	@sed "s|NAMESPACE|$(ARTIFACT_NAMESPACE)|g" $(K8S_RESOURCE_DOGU_CR_TEMPLATE_YAML) | sed "s|NAME|$(ARTIFACT_ID)|g"  | sed "s|VERSION|$(VERSION)|g" > $@
