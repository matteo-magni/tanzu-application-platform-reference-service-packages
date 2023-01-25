#!/usr/bin/env bash

set -euo pipefail

echo ">> Local Test"

SCRIPT_FOLDER=$(basename $0 .sh)

# SCRIPT_COMMON=${SCRIPT_FOLDER}/common.sh
# [ -x ${SCRIPT_COMMON} ] && source ${SCRIPT_COMMON}

[ -z "${CROSSPLANE_NAMESPACE:-}" ] && ( echo "The CROSSPLANE_NAMESPACE environment variable must be defined" ; exit 1 )

kubectl create namespace ${CROSSPLANE_NAMESPACE} || true

pushd $(dirname $0)

# install provider as well as its ProviderConfig only if the INSTALL_PROVIDER environment variable is not empty
[ -z "${INSTALL_PROVIDER:-}" ] || ./crossplane-install-azure-provider.sh

# install the Crossplane configuration
./${SCRIPT_FOLDER}/install-package.sh

# create the Crossplane claim
./${SCRIPT_FOLDER}/claim-instance.sh

# deploy application and test
./${SCRIPT_FOLDER}/test.sh

popd
