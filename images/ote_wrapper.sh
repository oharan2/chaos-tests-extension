#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

secretDir=/secret/es
# Fail-closed: live *-commands.sh use nounset + $(<file) with no || true.
ES_PASSWORD=$(<"${secretDir}/es-password--${CHAOS_TEAM_NAME}")
ES_USERNAME=$(<"${secretDir}/es-username--${CHAOS_TEAM_NAME}")
export ES_PASSWORD ES_USERNAME
case "${CHAOS_TEAM_NAME}" in
  chaos) ES_SERVER="https://search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com" ;;
  lp-chaos) ES_SERVER="https://open-search.lp-chaos--svc--web-app.chaos.lp.devcluster.openshift.com" ;;
  *) ES_SERVER="" ;;
esac
export ES_SERVER

telemetry_password=$(cat "/secret/telemetry/telemetry_password")
export TELEMETRY_PASSWORD="${telemetry_password}"

oc config view --flatten > /tmp/config
export KUBECONFIG=/tmp/config
export KRKN_KUBE_CONFIG="${KUBECONFIG}"
if [[ -n "${TARGET_NAMESPACE:-}" ]]; then
  export NAMESPACE="${TARGET_NAMESPACE}"
fi

if [[ -n "${SHARED_DIR:-}" && -f "${SHARED_DIR}/health-check-url" ]]; then
  HEALTH_CHECK_URL=$(cat "${SHARED_DIR}/health-check-url" || true)
fi
if [[ -z "${HEALTH_CHECK_URL:-}" ]]; then
  console_url=$(oc get routes -n openshift-console console -o jsonpath='{.spec.host}')
  export HEALTH_CHECK_URL="https://${console_url}"
else
  export HEALTH_CHECK_URL
fi

if [[ "${OTE_AWS_SETUP:-}" == "cluster-profile" || "${OTE_AWS_SETUP:-}" == "zone-outage" ]]; then
  mkdir -p "${HOME}/.aws"
  if [[ "${OTE_AWS_SETUP}" == "zone-outage" && -f /secret/telemetry/.awscred ]]; then
    cat /secret/telemetry/.awscred > "${HOME}/.aws/config"
  fi
  if [[ -n "${CLUSTER_PROFILE_DIR:-}" && -f "${CLUSTER_PROFILE_DIR}/.awscred" ]]; then
    cat "${CLUSTER_PROFILE_DIR}/.awscred" > "${HOME}/.aws/config"
    export AWS_SHARED_CREDENTIALS_FILE="${CLUSTER_PROFILE_DIR}/.awscred"
  fi
  aws_region="${REGION:-${LEASED_RESOURCE:-}}"
  export AWS_DEFAULT_REGION="${aws_region}"
fi
if [[ "${OTE_AWS_SETUP:-}" == "zone-outage" ]]; then
  NODE_NAME=$(oc get nodes --no-headers | head -n 1 | awk '{print $1}')
  VPC_ID=$(aws ec2 describe-instances --filter Name=private-dns-name,Values="${NODE_NAME}" --query 'Reservations[*].Instances[*].NetworkInterfaces[*].VpcId' --output text)
  export VPC_ID
  # Verbatim from live zone-outage-commands.sh: no --output text (JSON-shaped).
  SUBNET_ID=$(aws ec2 describe-subnets --filter Name=vpc-id,Values="${VPC_ID}" --query 'Subnets[*].SubnetId' --max-items 2)
  export SUBNET_ID
fi

collect_artifacts() {
  local rc=$?
  set +o errexit
  if [[ "${TELEMETRY_EVENTS_BACKUP:-}" == "True" && -f /tmp/events.json ]]; then
    cp /tmp/events.json "${ARTIFACT_DIR}/events.json"
  fi
  if [[ -f /tmp/report.out.pdf ]]; then
    cp /tmp/report.out.pdf "${ARTIFACT_DIR}/kraken.report.pdf"
  fi
  exit "${rc}"
}
trap collect_artifacts EXIT

export PYTHONPATH="${PYTHONPATH:-/home/krkn/krkn-hub/packages}"
exec "$@"
