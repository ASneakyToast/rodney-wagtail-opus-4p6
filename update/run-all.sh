#!/usr/bin/env bash
# update/run-all.sh -- Run all page update scripts in sequence
# This updates an EXISTING page (TARGET_PAGE_ID) rather than creating a new one.
set -euo pipefail

UPDATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$UPDATE_DIR/../config/env.sh"
source "$UPDATE_DIR/../lib/rodney-helpers.sh"

echo "========================================"
echo "  Wagtail Page Update Phase"
echo "  Target: ${WAGTAIL_ADMIN_URL}"
echo "  Page ID: ${TARGET_PAGE_ID}"
echo "  Content: Design Strategy MBA"
echo "========================================"
echo ""

ensure_browser
# Note: not stopping browser on exit -- needed for subsequent verification phase

SCRIPTS=(
    01-login.sh
    02-navigate-to-edit.sh
    03-audit-existing-blocks.sh
    04-set-display-template.sh
    05-update-basic-fields.sh
    06-clear-and-fill-body.sh
    07-publish.sh
)

total=${#SCRIPTS[@]}
current=0

for script in "${SCRIPTS[@]}"; do
    current=$((current + 1))
    echo ""
    echo "========================================="
    echo "  [${current}/${total}] Running update/${script}"
    echo "========================================="

    if ! bash "$UPDATE_DIR/$script"; then
        echo ""
        echo "  [FAILED] update/${script} failed!" >&2
        echo "  Stopping. Fix the issue and re-run from this step:" >&2
        echo "    bash update/${script}" >&2
        take_named_screenshot "error-update-failed-at-${script%.sh}"
        exit 1
    fi
done

echo ""
echo "========================================"
echo "  Page Update Complete!"
echo "  Screenshots: ${SCREENSHOT_DIR}/"
echo "========================================"
