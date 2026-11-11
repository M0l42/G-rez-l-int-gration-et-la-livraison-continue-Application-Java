#!/usr/bin/env bash
# run-tests.sh - unified test runner, identical in every repo.
#
# Detects the project type, runs its unit tests and copies the JUnit XML
# reports into ./test-results/.
#
# Exit codes:
#   0  tests passed
#   1  tests failed, or no JUnit XML report was produced
#   2  unknown project type (no package.json or build.gradle)
#   3  a required tool is missing
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"
RESULTS_DIR="test-results"

die()  { echo "run-tests: $2" >&2; exit "$1"; }
need() { command -v "$1" >/dev/null 2>&1 || die 3 "missing required tool: $1"; }

# ---- Detect project type ----
if [[ -f package.json ]]; then
  TYPE=node
elif [[ -f build.gradle || -f build.gradle.kts ]]; then
  TYPE=gradle
else
  die 2 "unknown project type: no package.json or build.gradle in $(pwd)"
fi
echo "run-tests: detected $TYPE project"

# ---- Check required tools (before touching any files) ----
case "$TYPE" in
  node)
    need node
    need npm
    ;;
  gradle)
    need java
    [[ -x ./gradlew ]] || die 3 "./gradlew is missing or not executable"
    ;;
esac

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# ---- Run tests (keep going on failure so reports are still collected) ----
status=0
case "$TYPE" in
  node)
    rm -rf reports
    [[ -d node_modules ]] || npm ci
    npx ng test --watch=false --browsers=ChromeHeadless || status=$?
    reports=(reports/*.xml)
    ;;
  gradle)
    ./gradlew clean test --no-daemon || status=$?
    reports=(build/test-results/test/*.xml)
    ;;
esac

# ---- Collect reports ----
(( ${#reports[@]} > 0 )) || die 1 "no JUnit XML report produced"
cp "${reports[@]}" "$RESULTS_DIR"/
echo "run-tests: copied ${#reports[@]} report(s) to $RESULTS_DIR/"

(( status == 0 )) && echo "run-tests: tests passed" || echo "run-tests: tests FAILED (exit $status)" >&2
exit "$status"
