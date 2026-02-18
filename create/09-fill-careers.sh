#!/usr/bin/env bash
# create/09-fill-careers.sh -- Fill the Careers section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="careers"
echo "=== Create Step 9: Fill Careers Section ==="

section_json=$(get_section_data "$SECTION_ID")

# 1. Heading block: headline + subhead
headline=$(section_field "$section_json" ".fields.headline")
subhead=$(section_field "$section_json" ".fields.subhead")
add_heading_block "$headline" "$subhead"

# 2. Paragraph block: body
body=$(section_field "$section_json" ".fields.body")
if [[ -n "$body" ]]; then
    add_paragraph_block "$body"
fi

# 3. Paragraph block: secondary_body
sec_body=$(section_field "$section_json" ".fields.secondary_body")
if [[ -n "$sec_body" ]]; then
    add_paragraph_block "$sec_body"
fi

take_named_screenshot "create-09-careers"

echo "=== Create Step 9 complete ==="
