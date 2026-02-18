#!/usr/bin/env bash
# lib/section-helpers.sh -- Common helpers for section-filling scripts
# Source after all config and library files are loaded.

DATA_FILE="${DATA_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/data/design-strategy-mba.json}"

# Read a section's data by ID
# Usage: section_json=$(get_section_data "overview")
get_section_data() {
    local section_id="$1"
    jq -r ".sections[] | select(.id == \"${section_id}\")" "$DATA_FILE"
}

# Read a field from section JSON
# Usage: value=$(section_field "$section_json" ".fields.headline")
section_field() {
    local json="$1"
    local path="$2"
    echo "$json" | jq -r "$path // empty"
}

# Add a Heading block (CharBlock - single text value)
add_heading_block() {
    local headline="$1"
    local subhead="${2:-}"

    # Combine headline and subhead if both present
    local heading_text="$headline"
    if [[ -n "$subhead" ]]; then
        heading_text="${headline} — ${subhead}"
    fi

    streamfield_add_block "body" "Heading"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    echo "  Heading: ${heading_text}"
    streamfield_fill_value "$block_sel" "$heading_text"
}

# Add a Paragraph block (RichTextBlock - Draftail editor)
add_paragraph_block() {
    local text="$1"

    streamfield_add_block "body" "Paragraph"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    echo "  Setting paragraph content (${#text} chars)..."
    draftail_set_content "$block_sel" "$text"
}

# Add a Quote block (may be CharBlock or StructBlock - we'll detect)
add_quote_block() {
    local quotation="$1"
    local citation_name="${2:-}"

    streamfield_add_block "body" "Quote"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    # Check if this is a StructBlock (has sub-contentpath elements) or CharBlock
    local has_subfields
    has_subfields=$($RODNEY_CMD js "
        document.querySelector('${block_sel} [data-contentpath]') ? 'struct' : 'char'
    " 2>/dev/null || echo "char")

    if [[ "$has_subfields" == "struct" ]]; then
        echo "  Quote (struct): \"${quotation:0:50}...\""
        streamfield_fill_field "$block_sel" "quotation" "$quotation"
        if [[ -n "$citation_name" ]]; then
            streamfield_fill_field "$block_sel" "citation_name" "$citation_name"
        fi
    else
        # CharBlock - combine quote and attribution
        local quote_text="$quotation"
        if [[ -n "$citation_name" ]]; then
            quote_text="${quotation} — ${citation_name}"
        fi
        echo "  Quote (char): \"${quote_text:0:60}...\""
        streamfield_fill_value "$block_sel" "$quote_text"
    fi
}

# Add an Embed block (may be CharBlock or StructBlock)
add_embed_block() {
    local url="$1"

    streamfield_add_block "body" "Embed"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    # Check structure
    local has_subfields
    has_subfields=$($RODNEY_CMD js "
        document.querySelector('${block_sel} [data-contentpath]') ? 'struct' : 'char'
    " 2>/dev/null || echo "char")

    if [[ "$has_subfields" == "struct" ]]; then
        echo "  Embed (struct): ${url}"
        streamfield_fill_field "$block_sel" "embed" "$url"
    else
        echo "  Embed (char): ${url}"
        streamfield_fill_value "$block_sel" "$url"
    fi
}

# Add a Small CTA block (likely StructBlock)
add_cta_block() {
    local label="$1"
    local url="$2"

    streamfield_add_block "body" "Small CTA"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    # Check structure
    local has_subfields
    has_subfields=$($RODNEY_CMD js "
        document.querySelector('${block_sel} [data-contentpath]') ? 'struct' : 'char'
    " 2>/dev/null || echo "char")

    echo "  CTA: ${label} -> ${url}"
    if [[ "$has_subfields" == "struct" ]]; then
        # Try Draftail for title, then fallback to text
        streamfield_fill_draftail "$block_sel" "title" "$label"
        streamfield_fill_field "$block_sel" "external_url" "$url"
    else
        # CharBlock - just put the URL
        streamfield_fill_value "$block_sel" "$url"
    fi
}

# Fill a section's standard fields: adds Heading + Paragraph blocks
# Usage: fill_section_standard_fields "overview"
fill_section_standard_fields() {
    local section_id="$1"
    local section_json
    section_json=$(get_section_data "$section_id")

    local headline subhead body
    headline=$(section_field "$section_json" ".fields.headline")
    subhead=$(section_field "$section_json" ".fields.subhead")
    body=$(section_field "$section_json" ".fields.body")

    # Add Heading block
    if [[ -n "$headline" ]]; then
        add_heading_block "$headline" "$subhead"
    fi

    # Add Paragraph block with body text
    if [[ -n "$body" ]]; then
        add_paragraph_block "$body"
    fi
}
