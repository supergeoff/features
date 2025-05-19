#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "mage is installed" mage --version

reportResults
