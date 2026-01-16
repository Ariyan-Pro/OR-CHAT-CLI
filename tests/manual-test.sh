#!/usr/bin/env bash
set -euo pipefail

echo "Manual Phase 2 tests"

echo "1) Missing key -> should fail"
unset OPENROUTER_API_KEY
if ../bin/orchat "hello" 2>/dev/null; then
  echo "FAILED: expected failure with missing key"
else
  echo "PASSED: missing key"
fi

echo "2) With dummy key (network will fail but our handling should trigger)"
export OPENROUTER_API_KEY="DUMMY"
../bin/orchat --help
