#!/usr/bin/env bash
# update/03-audit-existing-blocks.sh -- Audit what blocks currently exist in the body StreamField
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"

echo "=== Update Step 3: Audit Existing Blocks ==="

# Count existing blocks
BLOCK_COUNT=$(streamfield_count_blocks "body")
echo "  Existing body blocks: ${BLOCK_COUNT}"

# List block types and content previews
echo ""
echo "--- Current Block Inventory ---"
BLOCKS_JSON=$(streamfield_list_blocks "body")
echo "$BLOCKS_JSON" | jq '.' 2>/dev/null || echo "$BLOCKS_JSON"
echo "-------------------------------"

take_named_screenshot "update-03-audit"

echo ""
echo "  Strategy: Clear existing blocks and fill with new content from data file."
echo "  (Existing blocks will be removed and replaced with fresh content.)"
echo ""
echo "=== Update Step 3 complete ==="
