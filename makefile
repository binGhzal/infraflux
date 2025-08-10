SHELL := /bin/bash

.PHONY: help
help:
	@echo "Targets:"
	@echo "  build-cli     Build infraflux CLI"
	@echo "  fmt           Format Go code"
	@echo "  tree          Show repo tree (without .git)"
	@echo "  verify-yaml   Basic YAML lint (requires yq)"

.PHONY: build-cli
build-cli:
	cd cli && go build -o ../bin/infraflux ./main.go

.PHONY: fmt
fmt:
	cd cli && go fmt ./...

.PHONY: tree
tree:
	@find . -maxdepth 4 -not -path '*/\.git*' -print

.PHONY: verify-yaml
verify-yaml:
	@command -v yq >/dev/null || { echo "Install yq"; exit 1; }
	@find . -name '*.yaml' -o -name '*.yml' | xargs -I{} yq e 'true' {}
