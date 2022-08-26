#!/usr/bin/env bash
################################################################################
#  PROJECT: Squeak Bundle Generation
#  FILE:    test_bundle.sh
#  CONTENT: Test launching Squeak executable from a bundle
#
#  REQUIRES:
#    SMALLTALK_VERSION ... e.g., Squeak64-trunk
#    SMALLTALK_CI_HOME ... i.e., the path to smalltalkCI sources
#    tmp/Squeak.image
#    tmp/Squeak.changes
#    tmp/*.sources
#  PROVIDES:
#    tmp/*.xml             i.e., the test results
#
#  AUTHORS: Christoph Thiede, Hasso Plattner Institute, Potsdam, Germany
################################################################################

set -xo errexit

source "env_vars"
source "helpers.sh"

test_cli() {
  cp "${TMP_PATH}/Squeak.image" "${TMP_PATH}/Test.image"
  cp "${TMP_PATH}/Squeak.changes" "${TMP_PATH}/Test.changes"

  begin_group "Testing Squeak CLI..."
  pushd "${TMP_PATH}" > /dev/null
  output=$(timeout 10s "${SMALLTALK_VM}" -headless "Test.image" "--evaluate '2 + 3 * 4'" | tee /dev/tty | tail -n 1)
  (( "$output" = 20 ))
  popd > /dev/null
  end_group
}

test_cli
