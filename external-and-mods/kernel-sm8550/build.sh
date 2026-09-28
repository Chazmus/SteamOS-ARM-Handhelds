#!/usr/bin/env bash
# Kernel for SM8550, see ../kernel-common/build.sh and soc.env.
exec bash "$(dirname "${BASH_SOURCE[0]}")/../kernel-common/build.sh" sm8550 "$@"
