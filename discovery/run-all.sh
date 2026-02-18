#!/usr/bin/env bash
# discovery/run-all.sh -- Run all discovery phase scripts in sequence
set -euo pipefail

DISCOVERY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DISCOVERY_DIR/../config/env.sh"
source "$DISCOVERY_DIR/../lib/rodney-helpers.sh"

echo "========================================"
echo "  Wagtail Discovery Phase"
echo "  Target: ${WAGTAIL_ADMIN_URL}"
echo "========================================"
echo ""

ensure_browser
trap '$RODNEY_CMD stop 2>/dev/null || true' EXIT

for script in \
    01-login-and-explore.sh \
    02-discover-page-types.sh \
    03-inspect-page-form.sh \
    04-inspect-streamfield.sh \
    05-generate-selectors.sh; do

    echo ""
    echo "========================================="
    echo "  Running discovery/${script}"
    echo "========================================="
    bash "$DISCOVERY_DIR/$script"

    # Screenshot between steps for full documentation
    take_named_screenshot "discovery-after-${script%.sh}"
done

echo ""
echo "========================================"
echo "  Discovery Phase Complete"
echo "  Screenshots: ${SCREENSHOT_DIR}/"
echo "  Selectors: config/selectors.sh"
echo "========================================"
