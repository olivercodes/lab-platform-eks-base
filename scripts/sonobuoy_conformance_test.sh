#!/usr/bin/env bash
SONOBUOY_MODE=$1
CLUSTER_VERSION=$(kubectl version -o json | jq -r .serverVersion.gitVersion | cut -d- -f 1)

sonobuoy run --mode=${SONOBUOY_MODE} \
  --wait \
  --kube-conformance-image-version ${CLUSTER_VERSION} &

PROCESS_ID=$!

# Probe background jobs since CircleCI will kill a long running step if no output is produced for over 10min
while jobs %%; do
  echo "Waiting on Sonobuoy test to complete..."
  sleep 60
done

wait $PROCESS_ID

if ! sonobuoy status | grep -q -E ' +e2e +complete +passed +'; then
    TEST_EXIT_CODE=1
fi

mkdir sonobuoy_artifacts/
cd sonobuoy_artifacts
results=$(sonobuoy retrieve)
sonobuoy delete --wait
sonobuoy results $results
sonobuoy results $results --plugin e2e --mode detailed | jq 'select(.status=="failed")'

exit $TEST_EXIT_CODE