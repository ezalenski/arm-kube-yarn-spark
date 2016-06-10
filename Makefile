NAMESPACE=yarn-cluster
ENTITIES=namespace
MANIFESTS=./manifests

NAMESPACE_FILES_BASE=yarn-cluster-namespace.yaml
NAMESPACE_FILES=$(addprefix $(MANIFESTS)/,yarn-cluster-namespace.yaml)

HOSTS_DISCO_FILES_BASE=hosts-disco-service.yaml hosts-disco-controller.yaml
HOSTS_DISCO_FILES=$(addprefix $(MANIFESTS)/,$(HOSTS_DISCO_FILES_BASE))

HDFS_FILES_BASE=hdfs-nn-service.yaml hdfs-dn-service.yaml hdfs-nn-controller.yaml hdfs-dn-controller.yaml
HDFS_FILES=$(addprefix $(MANIFESTS)/,$(HDFS_FILES_BASE))

YARN_FILES_BASE=yarn-rm-service.yaml yarn-nm-service.yaml yarn-rm-controller.yaml yarn-nm-controller.yaml
YARN_FILES=$(addprefix $(MANIFESTS)/,$(YARN_FILES_BASE))

ZEPPELIN_FILES_BASE=zeppelin-service.yaml zeppelin-controller.yaml
ZEPPELIN_FILES=$(addprefix $(MANIFESTS)/,$(ZEPPELIN_FILES_BASE))

all: init create-apps
init: create-ns create-configmap create-service-account create-hosts-disco
clean: delete-apps delete-hosts-disco delete-configmap delete-service-account delete-ns
	while [[ -n `kubectl get ns -o json | jq 'select(.items[].status.phase=="Terminating") | true'` ]]; do echo "Waiting for $(NAMESPACE) namespace termination" ; sleep 5; done

### Executable dependencies
KUBECTL_BIN := $(shell command -v kubectl 2> /dev/null)
kubectl:
ifndef KUBECTL_BIN
	$(warning installing kubectl)
	curl -sf https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/darwin/amd64/kubectl > /usr/local/bin
endif
	$(eval KUBECTL := kubectl --namespace $(NAMESPACE))

WEAVE := $(shell command -v weave 2> /dev/null)
weave:
ifndef WEAVE
	$(warning Installing weave)
	curl --location --silent git.io/weave --output /usr/local/bin/weave
	chmod +x /usr/local/bin/weave
endif

# Create by file
$(MANIFESTS)/%.yaml: kubectl
	$(KUBECTL) create -f $@

# Delete by file
$(MANIFESTS)/%.yaml.delete: kubectl
	-$(KUBECTL) delete -f $(@:.delete=)

### Namespace
create-ns: $(NAMESPACE_FILES)
delete-ns: $(addsuffix .delete,$(NAMESPACE_FILES))


### Config Map
create-configmap: kubectl
	./manifests/make_hadoop_configmap.sh

delete-configmap: kubectl
	-$(KUBECTL) delete configmap hadoop-config

get-configmap: kubectl
	$(KUBECTL) get configmap hadoop-config -o=yaml


### Service Account
create-service-account: kubectl
	$(KUBECTL) create -f manifests/service-account.yaml

delete-service-account: kubectl
	-$(KUBECTL) delete serviceaccount yarn-cluster


### Hosts disco
create-hosts-disco: kubectl $(HOSTS_DISCO_FILES)
	while [[ -z `$(KUBECTL) get pods -o json | jq 'select(.items[].metadata.labels.component=="hosts-disco" and .items[].status.phase=="Running") | select(.items|length>1) | true'` ]]; do echo "Waiting for hosts-disco creation" ; sleep 2; done

delete-hosts-disco: $(addsuffix .delete,$(HOSTS_DISCO_FILES))

### All apps
create-apps: create-hdfs create-yarn create-zeppelin get-nn-pod get-rm-pod get-zeppelin-pod
delete-apps: delete-zeppelin delete-yarn delete-hdfs


### HDFS
create-hdfs: $(HDFS_FILES)
delete-hdfs: $(addsuffix .delete,$(HDFS_FILES))


### YARN
create-yarn: $(YARN_FILES)
delete-yarn: delete-yarn-rm-pf $(addsuffix .delete,$(YARN_FILES))


### Zeppelin
create-zeppelin: $(ZEPPELIN_FILES)
delete-zeppelin: delete-zeppelin-controller-pf $(addsuffix .delete,$(ZEPPELIN_FILES))


### Helper targets
get-ns: kubectl
	$(KUBECTL) get ns

get-rc: kubectl
	$(KUBECTL) get rc

get-pods: kubectl
	$(KUBECTL) get pods

get-svc: kubectl
	$(KUBECTL) get services

wait-for-%-pod: kubectl
	while [[ -z `$(KUBECTL) get pods -o json | jq 'select(.items[].metadata.labels.component=="'$*'" and .items[].status.phase=="Running") | true'` ]]; do echo "Waiting for $* pod" ; sleep 2; done

get-nn-pod: wait-for-hdfs-nn-pod
	$(eval NAMENODE_POD := $(shell $(KUBECTL) get pods -l component=hdfs-nn -o jsonpath={.items..metadata.name}))
	echo $(NAMENODE_POD)

get-dn-pod: wait-for-hdfs-dn-pod
	$(eval DATANODE_POD := $(shell $(KUBECTL) get pods -l component=hdfs-dn -o jsonpath={.items..metadata.name}))
	echo $(DATANODE_POD)

get-rm-pod: wait-for-yarn-rm-pod
	$(eval RESOURCE_MANAGER_POD := $(shell $(KUBECTL) get pods -l component=yarn-rm -o jsonpath={.items..metadata.name}))
	echo $(RESOURCE_MANAGER_POD)

get-zeppelin-pod: wait-for-zeppelin-pod
	$(eval ZEPPELIN_POD := $(shell $(KUBECTL) get pods -l component=zeppelin -o jsonpath={.items..metadata.name}))
	echo $(ZEPPELIN_POD)

get-canary-pod: kubectl
	$(eval CANARY_POD := $(shell kubectl --namespace kube-system get pod --selector=app=kubernetes-dashboard-canary -o jsonpath={.items..metadata.name}))
	echo $(CANARY_POD)

nn-logs: kubectl get-nn-pod
	$(KUBECTL) logs $(NAMENODE_POD)

nn-shell: kubectl get-nn-pod
	$(KUBECTL) exec -it $(NAMENODE_POD) -- bash

dn-shell: kubectl get-dn-pod
	$(KUBECTL) exec -it $(DATANODE_POD) -- bash

dfsreport: kubectl get-nn-pod
	$(KUBECTL) exec -it $(NAMENODE_POD) -- /usr/local/hadoop/bin/hdfs dfsadmin -report

rm-shell: kubectl get-rm-pod
	$(KUBECTL) exec -it $(RESOURCE_MANAGER_POD) -- bash

rm-logs: kubectl get-rm-pod
	$(KUBECTL) exec -it $(RESOURCE_MANAGER_POD) -- bash -c 'tail -f $$HADOOP_PREFIX/logs/*.log'

rm-pf: get-rm-pod
	$(KUBECTL) port-forward $(RESOURCE_MANAGER_POD) 8088:8088 2>/dev/null &

zeppelin-shell: get-zeppelin-pod
	$(KUBECTL) exec -it $(ZEPPELIN_POD) -- bash

zeppelin-pf: get-zeppelin-pod
	$(KUBECTL) port-forward $(ZEPPELIN_POD) 8081:8080 2>/dev/null &

port-forward: rm-pf zeppelin-pf

canary-pf: get-canary-pod
	kubectl --namespace kube-system port-forward $(CANARY_POD) 31999:9090 2>/dev/null &

delete-%-pf: kubectl
	-pkill -f "kubectl.*port-forward.*$*.*"

delete-pf: kubectl delete-dashboard-canary-pf delete-zeppelin-controller-pf delete-yarn-rm-pf

### Local cluster targets
KID := $(shell command -v kid 2> /dev/null)
kid:
ifndef KID
	$(warning Installing Kubernetes In Docker (kid))
	curl -sfL https://raw.githubusercontent.com/danisla/kid/docker-mac/kid > /usr/local/bin/kid
	chmod +x /usr/local/bin/kid
endif

# Discovery via docker.local address
avahi:
	docker run -d --name avahi-docker --net host --restart always -e AVAHI_HOST=docker danisla/avahi:latest
stop-avahi:
	docker kill avahi-docker && docker rm avahi-docker

kid-up: kid avahi
	kid up

kid-down: clean delete-pf
	kid down

start-k8s: weave kubectl
	# weave
	weave launch
	weave expose -h moby.weave.local

	# Kubernetes Anywhere
	docker run --rm \
	  --volume="/:/rootfs" \
	  --volume="/var/run/weave/weave.sock:/docker.sock" \
	    weaveworks/kubernetes-anywhere:toolbox-v1.2 \
	      sh -c 'setup-single-node && compose -p kube up -d'

	# SkyDNS
	kubectl create -f https://git.io/vrjpn

	# Canary Dashboard
	kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard-canary.yaml

	# Test it out
	kubectl cluster-info

stop-k8s: weave kubectl clean delete-pf
	# Delete SkyDNS
	-kubectl delete -f https://git.io/vrjpn
	# Delete Canary Dashboard
	-kubectl delete -f kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard-canary.yaml
	-docker run --rm \
	  --volume="/:/rootfs" \
	  --volume="/var/run/weave/weave.sock:/docker.sock" \
	    weaveworks/kubernetes-anywhere:toolbox-v1.2 \
	      sh -c 'setup-single-node && compose -p kube down'
	-weave stop