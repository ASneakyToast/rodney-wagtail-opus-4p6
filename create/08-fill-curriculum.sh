#!/usr/bin/env bash
# create/08-fill-curriculum.sh -- Fill the Curriculum section
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/env.sh"
source "$SCRIPT_DIR/../config/selectors.sh"
source "$SCRIPT_DIR/../lib/rodney-helpers.sh"
source "$SCRIPT_DIR/../lib/streamfield.sh"
source "$SCRIPT_DIR/../lib/draftail.sh"
source "$SCRIPT_DIR/../lib/section-helpers.sh"

SECTION_ID="curriculum"
echo "=== Create Step 8: Fill Curriculum Section ==="

section_json=$(get_section_data "$SECTION_ID")
block_sel=$(fill_section_standard_fields "$SECTION_ID")

# Secondary subhead and body
sec_subhead=$(section_field "$section_json" ".fields.secondary_subhead")
sec_body=$(section_field "$section_json" ".fields.secondary_body")
if [[ -n "$sec_subhead" ]]; then
    echo "  Secondary subhead: ${sec_subhead}"
    streamfield_fill_field "$block_sel" "secondary_subhead" "$sec_subhead"
fi
if [[ -n "$sec_body" ]]; then
    echo "  Setting secondary body content..."
    draftail_set_content "${block_sel} [data-contentpath=\"secondary_body\"]" "$sec_body"
fi

# Pull quote
quote=$(section_field "$section_json" ".fields.pull_quote.quote")
attribution=$(section_field "$section_json" ".fields.pull_quote.attribution")
if [[ -n "$quote" ]]; then
    fill_pull_quote "$block_sel" "$quote" "$attribution"
fi

take_named_screenshot "create-08-curriculum"

echo "=== Create Step 8 complete ==="
