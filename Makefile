REGISTRY        ?= localhost
NAMESPACE       ?= centreon
TAG             ?= 24.10
ALMA            ?= 8

IMAGES := centreon-engine centreon-broker-sql centreon-broker-rrd centreon-gorgone centreon-web

.PHONY: help build $(addprefix build-,$(IMAGES)) push test-unit test-integration test-e2e \
        compose-up compose-down lint clean

help:
	@echo "Targets:"
	@echo "  build             Build the five Centreon images (MariaDB is consumed from bitnamilegacy)"
	@echo "  build-<name>      Build a single image (e.g. build-centreon-engine)"
	@echo "  push              Push all images to \$$REGISTRY"
	@echo "  lint              hadolint on every Dockerfile"
	@echo "  test-unit         pytest tests/unit (no containers required)"
	@echo "  test-integration  pytest tests/integration (needs compose-up)"
	@echo "  test-e2e          pytest tests/e2e (needs compose-up)"
	@echo "  compose-up        docker-compose up -d"
	@echo "  compose-down      docker-compose down -v"

build: $(addprefix build-,$(IMAGES))

build-%:
	docker build \
	  --build-arg ALMALINUX_VERSION=$(ALMA) \
	  --build-arg CENTREON_VERSION=$(TAG) \
	  -t $(REGISTRY)/$(NAMESPACE)/$*:$(TAG) \
	  images/$*

push:
	@for img in $(IMAGES); do \
	  docker push $(REGISTRY)/$(NAMESPACE)/$$img:$(TAG); \
	done

lint:
	@for img in $(IMAGES); do \
	  echo "=== hadolint images/$$img/Dockerfile ==="; \
	  hadolint images/$$img/Dockerfile || exit 1; \
	done

test-unit:
	pytest -v tests/unit

test-integration:
	pytest -v tests/integration

test-e2e:
	pytest -v tests/e2e

compose-up:
	docker-compose --env-file .env up -d
	@echo "Waiting for centreon-web to become healthy..."
	@for i in $$(seq 1 60); do \
	  curl -fsS http://localhost:8080/centreon/api/latest/platform/topology >/dev/null 2>&1 && break; \
	  sleep 5; \
	done

compose-down:
	docker-compose --env-file .env down -v

clean:
	@for img in $(IMAGES); do \
	  docker rmi $(REGISTRY)/$(NAMESPACE)/$$img:$(TAG) 2>/dev/null || true; \
	done
