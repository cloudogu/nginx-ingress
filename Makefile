MAKEFILES_VERSION=5.0.0

.DEFAULT_GOAL:=help

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk

K8S_CLUSTER_ROOT=/home/jsprey/Documents/GIT/k3ces
K8S_RESOURCE_DIR=${WORKDIR}/k8s
K8S_DEPLOYMENT_YAML=${K8S_RESOURCE_DIR}/nginx-deployment.yaml

# read registry and version from dockerfile
IMAGE=$(shell jq -r ".Image" dogu.json):$(shell jq -r ".Version" dogu.json)

##@ EcoSystem

.PHONY: build
build: docker-build image-import k8s-delete k8s-apply ## Builds a new version of the dogu and deploy it into the K8s-EcoSystem.

##@ Docker

.PHONY: docker-build
docker-build: ## Builds the docker image of the dogu with the name `registry.cloudogu.com/official/nginx-ingress:dev`.
	@echo "Building docker image of dogu..."
	docker build . -t ${IMAGE}

##@ Kubernetes

${K8S_CLUSTER_ROOT}/image.tar: # [not listed in help] Saves the `registry.cloudogu.com/official/nginx-ingress:dev` image into a file into the K8s root path to be available on all nodes.
	docker save ${IMAGE} -o ${K8S_CLUSTER_ROOT}/image.tar

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
	@kubectl delete -f ${K8S_RESOURCE_DIR} --ignore-not-found=true

.PHONY: k8s-apply
k8s-apply: ## Applies all dogu related resources from the K8s cluster.
	@echo "Apply new dogu resources..."
	@yq -i e "(.spec.template.spec.containers[]|select(.name == \"controller\").image)=\"${IMAGE}\"" ${K8S_DEPLOYMENT_YAML}
	@kubectl apply -f ${K8S_RESOURCE_DIR}
	@rm -f ${K8S_DEPLOYMENT_DEV_YAML_DEVELOPMENT}