SHELL := /bin/bash

.PHONY: help
help:
	@echo "Targets:"
	@echo "  build-cli     Build infraflux CLI"
	@echo "  fmt           Format Go code"
	@echo "  vet           Run go vet"
	@echo "  test          Run unit tests"
	@echo "  check         fmt + vet + test + yaml verify"
	@echo "  tree          Show repo tree (without .git)"
	@echo "  verify-yaml   Basic YAML lint (requires yq)"

.PHONY: build-cli
build-cli:
	cd cli && go build -o ../bin/infraflux ./main.go

.PHONY: fmt
fmt:
	cd cli && go fmt ./...

.PHONY: vet
vet:
	cd cli && go vet ./...

.PHONY: test
test:
	cd cli && go test ./...

.PHONY: check
check: fmt vet test verify-yaml

.PHONY: tree
tree:
	@find . -maxdepth 4 -not -path '*/\.git*' -print

# Limit YAML verification to our source manifests (exclude generated/examples/helm templates)
YAML_DIRS := clusters crossplane management recipes
.PHONY: verify-yaml
verify-yaml:
	@command -v yq >/dev/null || { echo "Install yq"; exit 1; }
	@echo "Verifying YAML in: $(YAML_DIRS)"
	@find $(YAML_DIRS) -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 | xargs -0 -I{} yq e 'true' {}

.PHONY: render-sample
render-sample: build-cli
	./bin/infraflux up --provider proxmox --name example-lab --workers 2 --cpu 2 --memory 4 --k8s 1.30 --recipes base,observability,devtools
	@echo "Rendered:"
	@find out/example-lab -type f | sed 's#^# - #'
