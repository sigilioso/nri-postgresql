export PATH := $(PATH):$(GOPATH)/bin
NATIVEOS    := $(shell go version | awk -F '[ /]' '{print $$4}')
NATIVEARCH  := $(shell go version | awk -F '[ /]' '{print $$5}')
INTEGRATION     := postgresql
GOFLAGS          = -mod=readonly # ignore the vendor directory and to report an error if go.mod needs to be updated.
BINARY_NAME      = nri-$(INTEGRATION)
INTEGRATIONS_DIR = /var/db/newrelic-infra/newrelic-integrations/
CONFIG_DIR       = /etc/newrelic-infra/integrations.d
GO_FILES        := ./src/

all: build

build: clean test compile

build-container:
	docker build -t nri-postgresql .

clean:
	@echo "=== $(INTEGRATION) === [ clean ]: Removing binaries and coverage file..."
	@rm -rfv bin coverage.xml

compile:
	@echo "=== $(INTEGRATION) === [ compile ]: Building $(BINARY_NAME)..."
	@go build -o bin/$(BINARY_NAME) $(GO_FILES)

test:
	@echo "=== $(INTEGRATION) === [ test ]: running unit tests..."
	@go test -race ./... -count=1


integration-test:
	@echo "=== $(INTEGRATION) === [ test ]: running integration tests..."
	@docker-compose -f tests/docker-compose.yml pull
	@go test -v -tags=integration ./tests/. || (ret=$$?; docker-compose -f tests/docker-compose.yml down && exit $$ret)
	@docker-compose -f tests/docker-compose.yml down

install: compile
	@echo "=== $(INTEGRATION) === [ install ]: installing bin/$(BINARY_NAME)..."
	@sudo install -D --mode=755 --owner=root --strip $(ROOT)bin/$(BINARY_NAME) $(INTEGRATIONS_DIR)/bin/$(BINARY_NAME)
	@sudo install -D --mode=644 --owner=root $(ROOT)$(INTEGRATION)-config.yml.sample $(CONFIG_DIR)/$(INTEGRATION)-config.yml.sample

# Include thematic Makefiles
include $(CURDIR)/build/ci.mk
include $(CURDIR)/build/release.mk

.PHONY: all build clean compile test integration-test install