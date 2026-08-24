# Makefile with help command

IMAGE ?= mcp-hello-go-server
BIN   ?= mcp-hello-go-server

# Version bump level for `make release`: patch (default), minor, or major.
BUMP ?= patch

# Version literal lives in server.go (var version = "X.Y.Z"); read it for builds.
VERSION := $(shell sed -n 's/^var version = "\([0-9.]*\)".*/\1/p' server.go)

# Published image coordinates for pulling/running release images locally.
REGISTRY ?= ghcr.io/mitchallen
TAG ?= latest
PUBLISHED_IMAGE ?= $(REGISTRY)/mcp-hello-go-server
CONTAINER ?= mcp-hello-go
HTTP_PORT ?= 8000

.PHONY: all
all: help

.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make build        - Build the binary (embeds version via -ldflags)"
	@echo "  make run          - Run the MCP server over stdio"
	@echo "  make run-http     - Run the MCP server over streamable HTTP (PORT, default 8000)"
	@echo "  make test         - Run the test suite (go test)"
	@echo "  make fmt          - Format the code (gofmt -w)"
	@echo "  make vet          - Run go vet"
	@echo "  make vulncheck    - Scan Go dependencies with govulncheck"
	@echo "  make check        - fmt check + vet + test + vulncheck (the CI gate)"
	@echo "  make tidy         - go mod tidy"
	@echo "  make release      - Bump version (BUMP=patch|minor|major) via a release PR, then tag"
	@echo "  make docker-build - Build the Docker image locally"
	@echo "  make docker-run   - Run the locally-built image over HTTP on port 8000"
	@echo "  make docker-pull  - Pull the published image (REGISTRY, TAG)"
	@echo "  make docker-up    - Pull and run the published image detached (HTTP_PORT, TAG)"
	@echo "  make docker-smoke - Smoke-test the running container's MCP endpoint (HTTP_PORT)"
	@echo "  make docker-test  - Up + smoke + down in one shot (CI gate for a published image)"
	@echo "  make docker-logs  - Follow logs of the running test container"
	@echo "  make docker-down  - Stop the running test container"
	@echo "  make scan         - Scan the Docker image for vulnerabilities (Trivy)"
	@echo "  make docker-rm    - Remove the Docker image"
	@echo "  make docker-prune - Prune unused Docker data"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make help         - Display this help message"

.PHONY: build
build:
	@echo "Building $(BIN) v$(VERSION)..."
	go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o $(BIN) .

.PHONY: run
run:
	MCP_TRANSPORT=stdio go run .

.PHONY: run-http
run-http:
	MCP_TRANSPORT=http HOST=0.0.0.0 PORT=$${PORT:-8000} go run .

.PHONY: test
test:
	@echo "Running tests..."
	go test ./...

.PHONY: fmt
fmt:
	gofmt -w .

.PHONY: vet
vet:
	go vet ./...

# Scan Go dependencies against the Go vulnerability database.
.PHONY: vulncheck
vulncheck:
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...

# The full local CI gate: formatting, vet, tests, and dependency vuln scan.
.PHONY: check
check:
	@test -z "$$(gofmt -l .)" || { echo "gofmt needed on:"; gofmt -l .; exit 1; }
	go vet ./...
	go test ./...
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...

.PHONY: tidy
tidy:
	go mod tidy

# Bump the version literal in server.go and release through a PR, so the tag is
# always built from a commit that passed CI. Opens a release/vX.Y.Z PR carrying
# the bump plus that version's CHANGELOG section, waits for the required checks
# (test, scan, govulncheck), merges it, tags vX.Y.Z — the tag triggers the GHCR
# and Docker Hub publish workflows — then creates the matching GitHub Release
# from the CHANGELOG section. Override with BUMP=minor or BUMP=major.
#
# Write the new version's CHANGELOG.md section BEFORE running; the release notes
# are only as good as that section, and the run aborts if it is missing. That one
# edit may be left uncommitted — it rides along in the release PR. Everything
# else must be committed first.
#
# Re-runnable: if a run stops (checks failed, merge declined), re-running resumes
# the existing release/vX.Y.Z branch and skips to whatever step is left, rather
# than bumping the version a second time. It won't re-tag or re-create a Release.
.PHONY: release
release:
	@command -v gh >/dev/null || { echo "gh (GitHub CLI) is required — https://cli.github.com/"; exit 1; }
	@test -z "$$(git status --porcelain -- ':!CHANGELOG.md')" || { echo "Working tree has changes other than CHANGELOG.md; commit or stash them first."; exit 1; }
	@branch=$$(git rev-parse --abbrev-ref HEAD); \
	test "$$branch" = "main" || { echo "Refusing to release from '$$branch'; switch to main."; exit 1; }
	@git fetch --quiet origin
	@cur=$(VERSION); \
	major=$$(echo $$cur | cut -d. -f1); minor=$$(echo $$cur | cut -d. -f2); patch=$$(echo $$cur | cut -d. -f3); \
	case "$(BUMP)" in \
	  major) major=$$((major+1)); minor=0; patch=0 ;; \
	  minor) minor=$$((minor+1)); patch=0 ;; \
	  patch) patch=$$((patch+1)) ;; \
	  *) echo "BUMP must be patch, minor, or major"; exit 1 ;; \
	esac; \
	version=$$major.$$minor.$$patch; \
	rel="release/v$$version"; \
	state=$$(gh pr list --head "$$rel" --state all --limit 1 --json state --jq '.[0].state // empty'); \
	url=$$(gh pr list --head "$$rel" --state all --limit 1 --json url --jq '.[0].url // empty'); \
	if [ "$$state" = "MERGED" ]; then \
		echo "Release PR for v$$version already merged ($$url) — resuming at the tag."; \
	else \
		if git ls-remote --exit-code --heads origin "$$rel" >/dev/null 2>&1; then \
			git show "origin/$$rel:CHANGELOG.md" | grep -qE "^## \[$$version\]" || { \
				echo "$$rel exists but its CHANGELOG.md has no '## [$$version]' section — add it on that branch and push."; exit 1; }; \
			echo "Resuming existing branch $$rel (no second version bump)."; \
			git checkout "$$rel" && git pull --ff-only; \
		elif git rev-parse -q --verify "refs/heads/$$rel" >/dev/null; then \
			echo "Resuming local-only branch $$rel — the push never landed (no second version bump)."; \
			git checkout "$$rel"; \
			grep -qE "^## \[$$version\]" CHANGELOG.md || { \
				echo "$$rel exists locally but its CHANGELOG.md has no '## [$$version]' section — add it on that branch, commit, then re-run."; exit 1; }; \
			git push -u origin "$$rel"; \
		else \
			grep -qE "^## \[$$version\]" CHANGELOG.md || { \
				echo "CHANGELOG.md has no entry for v$$version — add a '## [$$version] - YYYY-MM-DD' section (Keep a Changelog format, top of the file) before releasing."; exit 1; }; \
			echo "Preparing $$rel (bumping $$cur -> $$version) ..."; \
			git checkout -b "$$rel"; \
			sed -i.bak "s/^var version = \"[0-9.]*\"/var version = \"$$version\"/" server.go && rm -f server.go.bak; \
			git add server.go CHANGELOG.md; \
			git commit -m "Release v$$version"; \
			git push -u origin "$$rel"; \
		fi; \
		if [ -z "$$url" ]; then \
			url=$$(gh pr create --base main --head "$$rel" --title "Release v$$version" \
				--body "Version bump + CHANGELOG section for v$$version, opened by \`make release\`. Merging this tags v$$version, which triggers the GHCR and Docker Hub publishes."); \
		fi; \
		echo "Release PR: $$url"; \
		git checkout main; \
		echo "Waiting for the required checks (test, scan, govulncheck)..."; \
		tries=0; \
		until [ -n "$$(gh pr checks "$$url" --required 2>/dev/null)" ]; do \
			tries=$$((tries + 1)); \
			if [ "$$tries" -ge 30 ]; then \
				echo "No checks appeared on $$url after 5 minutes — nothing tagged."; exit 1; \
			fi; \
			sleep 10; \
		done; \
		gh pr checks "$$url" --watch --required --fail-fast --interval 15 || { \
			echo ""; \
			echo "Required checks did not pass — nothing was tagged and v$$version is NOT released."; \
			echo "Fix it on $$rel, push, then re-run 'make release' to resume."; \
			exit 1; }; \
		gh pr merge "$$url" --squash --delete-branch; \
	fi; \
	git checkout main; \
	git pull --ff-only; \
	if git rev-parse -q --verify "refs/tags/v$$version" >/dev/null; then \
		echo "Tag v$$version already exists locally — reusing it."; \
	else \
		git tag "v$$version"; \
	fi; \
	git push origin "v$$version"; \
	if gh release view "v$$version" >/dev/null 2>&1; then \
		echo "GitHub release v$$version already exists — leaving it as is."; \
	else \
		echo "Creating GitHub release v$$version..."; \
		notes=$$(awk -v v="$$version" '$$0 ~ "^## \\[" v "\\]" {flag=1; next} flag && /^## \[/ {exit} flag {print}' CHANGELOG.md); \
		printf '%s\n' "$$notes" | gh release create "v$$version" --title "v$$version" --notes-file - ; \
	fi; \
	echo "Released v$$version from a checked commit — the publish workflows will build and push the images."

.PHONY: docker-build
docker-build:
	@echo "Building Docker image locally..."
	docker build --build-arg VERSION=$(VERSION) -t $(IMAGE) .

.PHONY: docker-run
docker-run:
	docker run --rm -p 8000:8000 --name $(IMAGE) $(IMAGE)

.PHONY: docker-pull
docker-pull:
	@echo "Pulling $(PUBLISHED_IMAGE):$(TAG)..."
	docker pull $(PUBLISHED_IMAGE):$(TAG)

.PHONY: docker-up
docker-up: docker-pull
	-docker rm -f $(CONTAINER) 2>/dev/null || true
	docker run -d --rm -p $(HTTP_PORT):8000 --name $(CONTAINER) $(PUBLISHED_IMAGE):$(TAG)
	@echo "Running $(PUBLISHED_IMAGE):$(TAG) as '$(CONTAINER)'."
	@echo "Connect an HTTP MCP client to http://localhost:$(HTTP_PORT)/mcp"

.PHONY: docker-smoke
docker-smoke:
	@docker ps --filter "name=^/$(CONTAINER)$$" --filter "status=running" --format '{{.Names}}' \
	  | grep -q "^$(CONTAINER)$$" \
	  || { echo "FAIL: container '$(CONTAINER)' is not running. Start it with 'make docker-up'."; exit 1; }
	@echo "Smoke-testing MCP endpoint at http://localhost:$(HTTP_PORT)/mcp ..."
	@curl -fsS -L --max-time 10 \
	  -X POST http://localhost:$(HTTP_PORT)/mcp \
	  -H "Content-Type: application/json" \
	  -H "Accept: application/json, text/event-stream" \
	  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"make-smoke","version":"0"}}}' \
	  | grep -q '"name":"mcp-hello-go-server"' \
	  && echo "PASS: server responded to MCP initialize" \
	  || { echo "FAIL: no valid MCP initialize response on port $(HTTP_PORT). Is 'make docker-up' running?"; exit 1; }

.PHONY: docker-logs
docker-logs:
	docker logs -f $(CONTAINER)

.PHONY: docker-down
docker-down:
	@echo "Stopping $(CONTAINER)..."
	-docker stop $(CONTAINER)

.PHONY: docker-test
docker-test:
	@$(MAKE) --no-print-directory docker-up
	@printf "Waiting for MCP endpoint on port $(HTTP_PORT)"; \
	for i in $$(seq 1 30); do \
	  if curl -sS -o /dev/null --max-time 2 http://localhost:$(HTTP_PORT)/mcp 2>/dev/null; then break; fi; \
	  printf "."; sleep 1; \
	done; echo
	@$(MAKE) --no-print-directory docker-smoke; status=$$?; \
	  $(MAKE) --no-print-directory docker-down; \
	  exit $$status

.PHONY: scan
scan:
	@echo "Scanning $(IMAGE) for vulnerabilities (fixable CRITICAL/HIGH fail)..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy \
		image --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 $(IMAGE) \
		|| { echo "Vulnerabilities found (or image not built — run 'make docker-build')."; exit 1; }

.PHONY: docker-rm
docker-rm:
	@echo "Removing Docker image..."
	-docker rmi $(IMAGE)

.PHONY: docker-prune
docker-prune:
	@echo "Pruning unused Docker data..."
	docker system prune -f

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BIN)
	go clean
