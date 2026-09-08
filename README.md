# chaos-tests-extension

This repository is the Krkn chaos **OpenShift Tests Extension** product. Canonical location: [`github.com/RedHatQE/chaos-tests-extension`](https://github.com/RedHatQE/chaos-tests-extension). It wraps krkn-hub; it does not rewrite Krkn. It is not a fork of a `redhat-chaos` copy of this tree, and it does not live in `openshift-eng/openshift-tests-extension`.

## Binary and suites

Binary: `cmd/chaos-tests`. Suites: `chaos/disruption/pod` (11 specs) and `chaos/disruption/node` (9 specs). All first-slice specs start **informing**.

Prow / origin CLI is `openshift-tests run chaos/disruption/pod` or `openshift-tests run chaos/disruption/node`. Do not pass `--timeout` or `--max-parallel-tests`. `run-suite` exists only on this binary for local use.

OTE identity is unchanged under RedHatQE: `NewExtension("openshift", "external", "chaos")`, IST keys `testextension.redhat.io/component` + `/binary`, and `setup-out-of-payload`.

## Local

```
go test ./...
go build -o chaos-tests ./cmd/chaos-tests
./chaos-tests info
./chaos-tests list
./chaos-tests update
```

Optional gzip: `hack/build-tests-ext.sh` (not used by CI).

## Image

`images/Dockerfile.ci` is a composite (`tests` + krkn-hub from `chaos/prow-scripts` + `chaos-tests-ext.gz` from a golang builder stage). Origin extracts only the `.gz`; Python and hub must already be on the test-step filesystem. ci-operator YAML for that image is **not** in this repo.

When `openshift/release` is wired, clone paths are `ci-operator/config/RedHatQE/chaos-tests-extension/` and `core-services/prow/02_config/RedHatQE/chaos-tests-extension/`.

## Ownership

This repo owns the **extension binary** (module `github.com/RedHatQE/chaos-tests-extension`). It does not own krkn-hub or the lp-chaos periodics unless the chaos team explicitly hands those over.

Still chaos-owned:

- `redhat-chaos/lp-chaos` 5.1 periodics
- `chaos/prow-scripts` as the Dockerfile COPY source
- Secrets and profile: `cluster-secrets-aws-chaos`, `chaos-es-creds`, `aws-lp-chaos`, `devqe-secrets`
- Promotion may stay `namespace: chaos` if that ImageStream is what the jobs pull

## Module and registry

Module: `github.com/RedHatQE/chaos-tests-extension`. Library pin: `github.com/openshift-eng/openshift-tests-extension v0.0.0-20260812190735-a8b44e9f9fed`. No `replace`.

Scenario registry: `test/chaos/krkn_scenarios.json`. Wrapper: `images/ote_wrapper.sh` (replaces Prow `*-commands.sh`).
