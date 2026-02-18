#!/usr/bin/env bash
# create/08-fill-curriculum.sh -- Fill the Curriculum section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="curriculum"
echo "=== Create Step 8: Fill Curriculum Section ==="

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

# 4. Quote block: pull_quote
quote=$(section_field "$section_json" ".fields.pull_quote.quote")
attribution=$(section_field "$section_json" ".fields.pull_quote.attribution")
if [[ -n "$quote" ]]; then
    add_quote_block "$quote" "$attribution"
fi

take_named_screenshot "create-08-curriculum"

echo "=== Create Step 8 complete ==="
