#!/usr/bin/env bash
# Exits 1 while the SwiftPM setup gives up on a version lookup's first dropped connection, 0 once it recovers from each, 2 when a step fails another way.
set -u

fail_step() {
  echo "RESULT: $1 failed"
  exit 2
}

node_version=$(node --version) || fail_step "node --version"
system=$(uname -sm) || fail_step "uname"
cd ReproducerApp || fail_step "cd ReproducerApp"
yarn install --frozen-lockfile --non-interactive >../yarn-install.log 2>&1 || fail_step "yarn install"
react_native_version=$(node -p "require('react-native/package.json').version") || fail_step "reading react-native's version"
echo "node ${node_version}, ${system}, react-native ${react_native_version}"

rm -rf spm-artifacts
node --import ../drop-first-lookup.mjs node_modules/react-native/scripts/spm/download-spm-artifacts.js \
  --version nightly --flavor debug --output spm-artifacts >../setup.log 2>&1
setup_status=$?
rm -rf spm-artifacts
cat ../setup.log
echo "download-spm-artifacts.js exited ${setup_status}"

dropped_lookups=$(awk '/^\[drop-first-lookup\] attempt 1: / { printf "%s%s", separator, $4; separator = " " }' ../setup.log) ||
  fail_step "reading the setup log"
network_failures=$(grep -c '^\[drop-first-lookup\] request failed on the network: ' ../setup.log)

if [[ -z "${dropped_lookups}" ]]; then
  echo "RESULT: the setup made no version lookup"
  exit 2
fi
if [[ "${network_failures}" -ne 0 ]]; then
  echo "RESULT: ${network_failures} request(s) the reproducer did not drop failed on the network, so the run shows nothing"
  exit 2
fi
if grep -q "fetch failed" ../setup.log; then
  echo "RESULT: the setup exited ${setup_status} with \"fetch failed\" after one dropped connection to: ${dropped_lookups}"
  exit 1
fi
echo "RESULT: the setup recovered from one dropped connection to each of: ${dropped_lookups}"
exit 0
