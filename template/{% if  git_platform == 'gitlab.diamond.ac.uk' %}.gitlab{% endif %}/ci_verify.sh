#!/bin/bash

# CI to verify all the instances specified in this repo have valid configs.
# The intention here is to verify that any mounted config folder will work
# with the container image specified in values.yaml
#
# At present this will only work with IOCs because it uses ibek. To support
# other future services that don't use ibek, we will need to add a standard
# entrypoint for validating the config folder mounted at /config.

ROOT=$(realpath $(dirname ${0})/..)
ID="${CI_COMMIT_SHORT_SHA:-"local"}"
POD="bl01c-ci-${ID}-$(date +%s)"
set -xe
status=0

# use docker if available else use podman
if ! docker version &>/dev/null; then docker=podman; else docker=docker; fi

for service in ${ROOT}/services/*
do
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

exit $status
