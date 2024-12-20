#!/bin/bash

# CI to verify all the instances specified in this repo have valid configs.
# The intention here is to verify that any mounted config folder will work
# with the container image specified in values.yaml
#
# At present this will only work with IOCs because it uses ibek. To support
# other future services that don't use ibek, we will need to add a standard
# entrypoint for validating the config folder mounted at /config.

HERE=$(realpath $(dirname ${0}))
ROOT=$(realpath ${HERE}/../..)
ID="${CI_COMMIT_SHORT_SHA:-"local"}"
POD="bl01c-ci-${ID}-$(date +%s)"  # Fix name
set -xe
status=0
rm -rf ${ROOT}/.ci_work/
mkdir -p ${ROOT}/.ci_work

# copy the services to a temporary location to avoid dirtying the repo
cp -r ${ROOT}/services/* ${ROOT}/.ci_work/

for service in ${ROOT}/services/*/  # */ to skip files
do

    ### Lint each service chart and validate if schema given ###
    service_name=$(basename $service)

    # skip services appearing in ci_skip_checks
    checks=${HERE}/ci_skip_checks
    if [[ -f ${checks} ]] && grep -q ${service_name} ${checks}; then
        echo "Skipping ${service_name}"
        continue
    fi

    schema=$(cat ${service}/values.yaml | sed -rn 's/^# yaml-language-server: \$schema=(.*)/\1/p')
    if [ -n "${schema}" ]; then
        echo "{\"\$ref\": \"$schema\"}" > ${ROOT}/.ci_work/$service_name/values.schema.json
    fi
    helm dependency update ${ROOT}/.ci_work/$service_name
    helm lint ${ROOT}/.ci_work/$service_name --strict --values ${ROOT}/services/values.yaml

    ### Valiate each ioc config ###
    # Skip if subfolder has no config to validate
    if [ ! -f "${service}/config/ioc.yaml" ]; then
        continue
    fi

    # Get the container image that this service uses from values.yaml if supplied
    image=$(cat ${service}/values.yaml | sed -rn 's/^ +image: (.*)/\1/p')

    if [ -n "${image}" ]; then
        echo "Validating ${service} with ${image}"

        # This will fail and exit if the ioc.yaml is invalid
        tar cf - ${service}/config | \
        kubectl run ${POD} -iq --restart Never --image ${image} \
                --command -- bash -c "tar xf - \
                && cat ${service}/config/ioc.yaml \
                && ibek runtime generate ${service}/config/ioc.yaml /epics/ibek-defs/*" \
                &>/dev/null || { echo Failed; status=1; }
        kubectl wait --for=condition=ready=False --timeout=30s pod/${POD}
        kubectl logs ${POD}
        kubectl delete pod ${POD}

    fi
done

rm -r ${ROOT}/.ci_work

exit $status
