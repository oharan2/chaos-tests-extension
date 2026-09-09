#!/bin/bash
# Local-only helper: CI builds and gzips inside images/Dockerfile.ci build-ext stage.
set -euxo pipefail; shopt -s inherit_errexit
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o chaos-tests-ext ./cmd/chaos-tests
gzip -n -f chaos-tests-ext
true
