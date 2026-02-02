#!/bin/bash
# Compatibility wrapper for smart audit
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/audit-with-source-check.sh" "$@"
