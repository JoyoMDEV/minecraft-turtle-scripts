#!/bin/sh
set -e
cd "$(dirname "$0")/.."

status=0
for test_file in tests/*_test.lua; do
  echo "== $test_file =="
  if lua "$test_file"; then
    :
  else
    echo "FAILED: $test_file"
    status=1
  fi
done
exit $status
