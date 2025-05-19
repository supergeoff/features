#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "cobra-cli is installed" cobra-cli --help

reportResults
