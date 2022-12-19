#!/usr/bin/env bash

set -euo pipefail

export PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}
export APP_NAMESPACE=${APP_NAMESPACE:-services}
VALUES=$(kubectl -n ${PACKAGE_NAMESPACE} get packageinstalls.packaging.carvel.dev ${PACKAGE_METADATA_NAME} -o jsonpath='{.spec.values[0].secretRef.name}')
export NAME=$(kubectl -n ${PACKAGE_NAMESPACE} get secrets ${VALUES} -o jsonpath='{.data.values\.yml}' | base64 -d | yq .name)
APP_NAME=${APP_NAME:-spring-boot-postgres}
TIMEOUT="15m"
SLEEPSECONDS="5"

kubectl -n ${APP_NAMESPACE} delete deployments.apps ${APP_NAME} || true

ytt -f config/carvel/package-install -v refName="${PACKAGE_METADATA_NAME}" -v namespace=${PACKAGE_NAMESPACE} -v version=${PACKAGE_VERSION} | kubectl delete -f -

timeout --foreground -s TERM $TIMEOUT bash -c \
'while [[ ${RG_DELETED:-} != "1" ]]; do
    kubectl -n ${PACKAGE_NAMESPACE} get resourcegroups.resources.azure.com ${NAME} >/dev/null 2>&1 && echo "ResourceGroup ${NAME} found, waiting..." && sleep ${SLEEPSECONDS} || RG_DELETED=1
done'
