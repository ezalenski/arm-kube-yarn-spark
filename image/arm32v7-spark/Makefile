.PHONY: build_%

# Current apache hadoop releases: http://hadoop.apache.org/releases.html

SPARK_22_VERSION = 2.2.1

DOCKER = docker
DOCKER_REPO = ezalenski/arm32v7-spark

all: build

### Build hadoop 2.6 and 2.7 images with native libs.
build: build-$(SPARK_22_VERSION)
build-%: spark-%-bin-hadoop2.7.tgz
	$(DOCKER) build -t spark:$* \
	--build-arg SPARK_VERSION=$* \
	.

tag: tag-$(SPARK_22_VERSION)
tag-%:
	$(DOCKER) tag spark:$* $(DOCKER_REPO):$*

push: push-$(SPARK_22_VERSION)
push-%:
	$(DOCKER) push $(DOCKER_REPO):$*

### Fetch binary distribution from closest mirror
spark-%-bin-hadoop2.7.tgz:
	curl -sfL https://www.apache.org/dyn/closer.lua/spark/spark-$*/spark-$*-bin-hadoop2.7.tgz | \
		egrep -C 3 "We suggest" | \
		perl -n -e'/href="(.*?)"/ && print $$1' | \
		xargs curl -LO

# Keep intermediate downloads.
.PRECIOUS: spark-%-bin-hadoop2.7.tgz
