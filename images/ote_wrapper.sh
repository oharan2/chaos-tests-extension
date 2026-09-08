#!/bin/bash
# Krkn-hub wrapper for the chaos OTE product. Replaces Prow *-commands.sh:
# load ES, telemetry, and AWS setup, then exec hub prow_run.sh.
#
# Usage:
#   ote_wrapper.sh ./<scenario-dir>/prow_run.sh
#
# Required environment:
#   CHAOS_TEAM_NAME
# Optional environment:
#   TARGET_NAMESPACE SHARED_DIR OTE_AWS_SETUP CLUSTER_PROFILE_DIR
#   REGION LEASED_RESOURCE TELEMETRY_EVENTS_BACKUP ARTIFACT_DIR PYTHONPATH
set -euxo pipefail; shopt -s inherit_errexit

: "${1:?}"

function CollectArtifacts () {
    typeset rc="${?}"
    set +o errexit
    if [[ "${TELEMETRY_EVENTS_BACKUP:-}" == "True" && -f /tmp/events.json ]]; then
        cp /tmp/events.json "${ARTIFACT_DIR}/events.json"
    fi
    if [[ -f /tmp/report.out.pdf ]]; then
        cp /tmp/report.out.pdf "${ARTIFACT_DIR}/kraken.report.pdf"
    fi
    exit "${rc}"
}
trap CollectArtifacts EXIT

# Krkn-hub reads ES_PASSWORD / TELEMETRY_PASSWORD from the process environment.
typeset secretDir=/secret/es
set +x
ES_PASSWORD="$(<"${secretDir}/es-password--${CHAOS_TEAM_NAME}")"
ES_USERNAME="$(<"${secretDir}/es-username--${CHAOS_TEAM_NAME}")"
export ES_PASSWORD ES_USERNAME
TELEMETRY_PASSWORD="$(cat "/secret/telemetry/telemetry_password")"
export TELEMETRY_PASSWORD
set -x

case "${CHAOS_TEAM_NAME}" in
    chaos) ES_SERVER="https://search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com" ;;
    lp-chaos) ES_SERVER="https://open-search.lp-chaos--svc--web-app.chaos.lp.devcluster.openshift.com" ;;
    *) ES_SERVER="" ;;
esac
export ES_SERVER

( set +x
    oc config view --flatten > /tmp/config
    true
)
export KUBECONFIG=/tmp/config
export KRKN_KUBE_CONFIG="${KUBECONFIG}"
if [[ -n "${TARGET_NAMESPACE:-}" ]]; then
    export NAMESPACE="${TARGET_NAMESPACE}"
fi

typeset healthCheckUrl="${HEALTH_CHECK_URL:-}"
if [[ -n "${SHARED_DIR:-}" && -f "${SHARED_DIR}/health-check-url" ]]; then
    healthCheckUrl="$(cat "${SHARED_DIR}/health-check-url" || true)"
fi
if [[ -z "${healthCheckUrl}" ]]; then
    typeset consoleUrl
    consoleUrl="$(oc get routes -n openshift-console console -o jsonpath='{.spec.host}')"
    healthCheckUrl="https://${consoleUrl}"
fi
export HEALTH_CHECK_URL="${healthCheckUrl}"

if [[ "${OTE_AWS_SETUP:-}" == "cluster-profile" || "${OTE_AWS_SETUP:-}" == "zone-outage" ]]; then
    mkdir -p "${HOME}/.aws"
    if [[ "${OTE_AWS_SETUP}" == "zone-outage" && -f /secret/telemetry/.awscred ]]; then
        ( set +x
            cat /secret/telemetry/.awscred > "${HOME}/.aws/config"
            true
        )
    fi
    if [[ -n "${CLUSTER_PROFILE_DIR:-}" && -f "${CLUSTER_PROFILE_DIR}/.awscred" ]]; then
        ( set +x
            cat "${CLUSTER_PROFILE_DIR}/.awscred" > "${HOME}/.aws/config"
            true
        )
        export AWS_SHARED_CREDENTIALS_FILE="${CLUSTER_PROFILE_DIR}/.awscred"
    fi
    typeset awsRegion="${REGION:-${LEASED_RESOURCE:-}}"
    export AWS_DEFAULT_REGION="${awsRegion}"
fi
if [[ "${OTE_AWS_SETUP:-}" == "zone-outage" ]]; then
    typeset nodeName
    nodeName="$(oc get nodes -o jsonpath='{.items[0].metadata.name}')"
    VPC_ID="$(aws ec2 describe-instances --filter Name=private-dns-name,Values="${nodeName}" --query 'Reservations[*].Instances[*].NetworkInterfaces[*].VpcId' --output text)"
    export VPC_ID
    # Live zone-outage-commands.sh: no --output text (JSON-shaped).
    SUBNET_ID="$(aws ec2 describe-subnets --filter Name=vpc-id,Values="${VPC_ID}" --query 'Subnets[*].SubnetId' --max-items 2)"
    export SUBNET_ID
fi

export PYTHONPATH="${PYTHONPATH:-/home/krkn/krkn-hub/packages}"
exec "$@"
