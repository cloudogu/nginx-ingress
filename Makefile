MAKEFILES_VERSION=4.2.0
VERSION=1.1.1-1
DEV_IMAGE=registry.cloudogu.com/official/nginx-ingress:dev

.DEFAULT_GOAL:=help

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk

K8S_CLUSTER_ROOT=/home/jsprey/Documents/GIT/k3ces
K8S_RESOURCE_DIR=${WORKDIR}/k8s
K8S_DEPLOYMENT_DEV_YAML=${K8S_RESOURCE_DIR}/nginx-deployment.yaml
K8S_DEPLOYMENT_DEV_YAML_TEMPLATE=${K8S_DEPLOYMENT_DEV_YAML}.tpl

##@ Help

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ EcoSystem

.PHONY: build
build: docker-build image-import k8s-delete k8s-apply ## Builds a new version of the dogu and deploy it into the K8s-EcoSystem.

##@ Docker

.PHONY: docker-build
docker-build: ## Builds the docker image of the dogu with the name `registry.cloudogu.com/official/nginx-ingress:dev`.
	@echo "Building docker image of dogu..."
	docker build . -t ${DEV_IMAGE}

##@ Kubernetes

${K8S_CLUSTER_ROOT}/image.tar: # [not listed in help] Saves the `registry.cloudogu.com/official/nginx-ingress:dev` image into a file into the K8s root path to be available on all nodes.
	docker save ${DEV_IMAGE} -o ${K8S_CLUSTER_ROOT}/image.tar

.PHONY: image-import
image-import: ${K8S_CLUSTER_ROOT}/image.tar ## Imports the currently available image `registry.cloudogu.com/official/nginx-ingress:dev` into the K8s cluster for all nodes.
	@echo "Import docker image of dogu into all K8s nodes..."
	cd ${K8S_CLUSTER_ROOT} && vagrant ssh main -- -t "sudo k3s ctr images import /vagrant/image.tar"
	cd ${K8S_CLUSTER_ROOT} && vagrant ssh worker-0 -- -t "sudo k3s ctr images import /vagrant/image.tar"
	cd ${K8S_CLUSTER_ROOT} && vagrant ssh worker-1 -- -t "sudo k3s ctr images import /vagrant/image.tar"
	rm ${K8S_CLUSTER_ROOT}/image.tar

.PHONY: k8s-delete
k8s-delete: ## Deletes all dogu related resources from the K8s cluster.
	@echo "Delete old dogu resources..."
	kubectl delete -f ${K8S_RESOURCE_DIR}

.PHONY: ${K8S_DEPLOYMENT_DEV_YAML}
${K8S_DEPLOYMENT_DEV_YAML}: # [not listed in help] Templates the deployment yaml with the development image.
	yq e "(.spec.template.spec.containers[]|select(.name == \"controller\").image)=\"${DEV_IMAGE}\"" ${K8S_DEPLOYMENT_DEV_YAML_TEMPLATE} > ${K8S_DEPLOYMENT_DEV_YAML}

.PHONY: k8s-apply
k8s-apply: ${K8S_DEPLOYMENT_DEV_YAML} ## Applies all dogu related resources from the K8s cluster.
	@echo "Apply new dogu resources..."
	kubectl apply -f ${K8S_RESOURCE_DIR}
	rm -f ${K8S_DEPLOYMENT_DEV_YAML}



