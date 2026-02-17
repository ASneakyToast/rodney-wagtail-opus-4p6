#!/usr/bin/env bash
# create/run-all.sh -- Run all creation phase scripts in sequence
set -euo pipefail

CREATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CREATE_DIR/../config/env.sh"
source "$CREATE_DIR/../lib/rodney-helpers.sh"

echo "========================================"
echo "  Wagtail Content Creation Phase"
echo "  Target: ${WAGTAIL_ADMIN_URL}"
echo "  Content: Design Strategy MBA"
echo "========================================"
echo ""

ensure_browser
# Browser cleanup handled by the caller

SCRIPTS=(
    01-login.sh
    02-navigate-to-parent.sh
    03-create-page.sh
    04-fill-basic-fields.sh
    05-fill-overview.sh
    06-fill-studios.sh
    07-fill-faculty.sh
    08-fill-curriculum.sh
    09-fill-careers.sh
    10-fill-news.sh
    11-fill-apply.sh
    12-publish.sh
)

total=${#SCRIPTS[@]}
current=0

for script in "${SCRIPTS[@]}"; do
    current=$((current + 1))
    echo ""
    echo "========================================="
    echo "  [${current}/${total}] Running create/${script}"
    echo "========================================="

    if ! bash "$CREATE_DIR/$script"; then
        echo ""
        echo "  [FAILED] create/${script} failed!" >&2
        echo "  Stopping. Fix the issue and re-run from this step:" >&2
        echo "    bash create/${script}" >&2
        take_named_screenshot "error-pipeline-failed-at-${script%.sh}"
        exit 1
    fi
done

echo ""
echo "========================================"
echo "  Content Creation Complete!"
echo "  Screenshots: ${SCREENSHOT_DIR}/"
echo "========================================"
