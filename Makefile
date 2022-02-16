MAKEFILES_VERSION=4.2.0
VERSION=1.1.1-1
DEV_IMAGE=registry.cloudogu.com/official/nginx-ingress:dev
K3CES=/home/jsprey/Documents/GIT/k3ces

.DEFAULT_GOAL:=dogu-release

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk

k3ces:
	docker build . -t ${DEV_IMAGE}
	docker save ${DEV_IMAGE} -o ${K3CES}/image.tar
	cd ${K3CES} && vagrant ssh main -- -t "sudo k3s ctr images import /vagrant/image.tar"
	cd ${K3CES} && vagrant ssh worker-0 -- -t "sudo k3s ctr images import /vagrant/image.tar"
	cd ${K3CES} && vagrant ssh worker-1 -- -t "sudo k3s ctr images import /vagrant/image.tar"
	rm ${K3CES}/image.tar
	yq -y '(.spec.template.spec.containers[]|select(.name == "controller").image)|="${DEV_IMAGE}"' nginx-deployment.yaml > nginx-deployment-dev.yaml
	kubectl apply -f nginx-deployment-dev.yaml
	rm -f nginx-deployment-dev.yaml



