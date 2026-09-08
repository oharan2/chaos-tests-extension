#!/bin/bash
# Local-only helper: CI builds and gzips inside images/Dockerfile.ci build-ext stage.
set -euo pipefail
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o chaos-tests-ext ./cmd/chaos-tests
gzip -n -f chaos-tests-ext
