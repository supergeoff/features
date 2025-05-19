#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "mage is installed" mage --version
check "air version is equal to 1.61.5" air -v | grep 1.61.5

reportResults
