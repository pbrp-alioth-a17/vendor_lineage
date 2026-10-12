#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Build locally using the standard A17 environment; never deploy or flash.
set -eo pipefail
if [[ $# -lt 4 ]]; then
    echo "Usage: $0 <product> <release> <variant> <bootimage|recoveryimage|vendorbootimage> [m arguments]" >&2
    exit 2
fi
script=$(readlink -f -- "${BASH_SOURCE[0]}")
cd "$(dirname "$script")/../../../.."
source build/envsetup.sh
lunch "$1" "$2" "$3"
shift 3
recoverybuild "$@"
