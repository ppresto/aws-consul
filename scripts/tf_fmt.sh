#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
find ${SCRIPT_DIR}/../ -type f -name "*.tf" -not -path '*/.terraform/*' -exec terraform fmt -write {} \;