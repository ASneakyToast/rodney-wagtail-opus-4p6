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
# LEGACY: Prefer add_nav_headline_block for section headings
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

# Add a Nav Headline block (StructBlock with nav_heading and headline fields)
# This is the standard pattern for section headings in the flexible template.
# Fields: nav_heading (anchor/navigation text), headline (display headline)
# Usage: add_nav_headline_block "Overview" "Redesign business as usual"
add_nav_headline_block() {
    local nav_heading="$1"
    local headline="$2"

    streamfield_add_block "body" "Nav Headline"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    echo "  Nav Headline: nav_heading='${nav_heading}', headline='${headline}'"

    # Check if this is a StructBlock (expected)
    local has_subfields
    has_subfields=$($RODNEY_CMD js "
        document.querySelector('${block_sel} [data-contentpath]') ? 'struct' : 'char'
    " 2>/dev/null || echo "char")

    if [[ "$has_subfields" == "struct" ]]; then
        # Fill nav_heading field (try common field name variants)
        # Prioritize "heading" since that's the actual Wagtail field name for section_heading blocks
        local nav_filled="false"
        for field_name in "heading" "nav_heading" "nav_title" "navigation_heading" "anchor"; do
            local field_check
            field_check=$($RODNEY_CMD js "
                document.querySelector('${block_sel} [data-contentpath=\"${field_name}\"]') ? 'yes' : 'no'
            " 2>/dev/null || echo "no")
            if [[ "$field_check" == "yes" ]]; then
                streamfield_fill_field "$block_sel" "$field_name" "$nav_heading"
                nav_filled="true"
                echo "  Nav heading set via field: ${field_name}"
                break
            fi
        done
        if [[ "$nav_filled" == "false" ]]; then
            echo "  [warn] Could not find nav_heading field, trying first text input" >&2
            streamfield_fill_value "$block_sel" "$nav_heading"
        fi

        # Fill headline field (try common field name variants)
        # Prioritize "subheading" since that's the actual Wagtail field name for section_heading blocks
        local headline_filled="false"
        for field_name in "subheading" "headline" "title" "label" "display_heading"; do
            local field_check
            field_check=$($RODNEY_CMD js "
                document.querySelector('${block_sel} [data-contentpath=\"${field_name}\"]') ? 'yes' : 'no'
            " 2>/dev/null || echo "no")
            if [[ "$field_check" == "yes" ]]; then
                # Check if it's a Draftail (rich text) or plain input
                local is_draftail
                is_draftail=$($RODNEY_CMD js "
                    document.querySelector('${block_sel} [data-contentpath=\"${field_name}\"] .Draftail-Editor, ${block_sel} [data-contentpath=\"${field_name}\"] .public-DraftEditor-content') ? 'draftail' : 'plain'
                " 2>/dev/null || echo "plain")

                if [[ "$is_draftail" == "draftail" ]]; then
                    streamfield_fill_draftail "$block_sel" "$field_name" "$headline"
                else
                    streamfield_fill_field "$block_sel" "$field_name" "$headline"
                fi
                headline_filled="true"
                echo "  Headline set via field: ${field_name}"
                break
            fi
        done
        if [[ "$headline_filled" == "false" ]]; then
            echo "  [warn] Could not find headline field in Nav Headline block" >&2
        fi
    else
        # Fallback: CharBlock - combine nav_heading and headline
        echo "  Nav Headline is CharBlock, combining values"
        streamfield_fill_value "$block_sel" "${nav_heading} — ${headline}"
    fi
}

# Add a subhead as a Paragraph block with H3 formatting
# This follows the standard pattern where subheads are rendered as H3/H4 elements
# Usage: add_subhead_block "An MBA for creative changemakers"
add_subhead_block() {
    local text="$1"
    local level="${2:-header-three}"  # default to H3, can pass header-four

    streamfield_add_block "body" "Paragraph"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    echo "  Subhead (${level}): ${text}"

    # Build ContentState with heading block type
    local content_state
    content_state=$(heading_to_contentstate "$text" "$level")

    if [[ -z "$content_state" ]] || [[ "$content_state" == "null" ]]; then
        echo "  [error] Failed to build heading ContentState." >&2
        return 1
    fi

    # Inject via React component (same strategy as draftail_set_content)
    local injected
    injected=$($RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_sel}');
            if (!block) return 'no-block';
            const editorEl = block.querySelector('.Draftail-Editor');
            if (!editorEl) return 'no-editor';
            const fiberKey = Object.keys(editorEl).find(k => k.indexOf('reactInternalInstance') > -1 || k.indexOf('reactFiber') > -1);
            if (!fiberKey) return 'no-fiber';
            let node = editorEl[fiberKey];
            let inst = null;
            for (let i = 0; i < 20; i++) {
                if (node && node.stateNode && node.stateNode.onChange) { inst = node.stateNode; break; }
                if (node) node = node.return; else break;
            }
            if (!inst) return 'no-instance';
            const cs = ${content_state};
            const newState = window.Draftail.createEditorStateFromRaw(cs);
            if (!newState) return 'create-failed';
            inst.onChange(newState);
            if (inst.saveState) inst.saveState();
            return 'ok';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$injected" != "ok" ]]; then
        echo "  [warn] Subhead injection returned '${injected}', trying draftail_set_content fallback" >&2
        draftail_set_content "$block_sel" "$text"
    fi
}

# Add alumni stories as a Paragraph block with linked names
# Usage: add_alumni_block "$alumni_json_array"
add_alumni_block() {
    local alumni_json="$1"

    streamfield_add_block "body" "Paragraph"
    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    echo "  Alumni stories paragraph (linked names)..."

    # Build ContentState with linked alumni names
    local content_state
    content_state=$(alumni_to_contentstate "$alumni_json")

    if [[ -z "$content_state" ]] || [[ "$content_state" == "null" ]]; then
        echo "  [error] Failed to build alumni ContentState." >&2
        return 1
    fi

    # Inject via React component
    local injected
    injected=$($RODNEY_CMD js "
        (() => {
            const block = document.querySelector('${block_sel}');
            if (!block) return 'no-block';
            const editorEl = block.querySelector('.Draftail-Editor');
            if (!editorEl) return 'no-editor';
            const fiberKey = Object.keys(editorEl).find(k => k.indexOf('reactInternalInstance') > -1 || k.indexOf('reactFiber') > -1);
            if (!fiberKey) return 'no-fiber';
            let node = editorEl[fiberKey];
            let inst = null;
            for (let i = 0; i < 20; i++) {
                if (node && node.stateNode && node.stateNode.onChange) { inst = node.stateNode; break; }
                if (node) node = node.return; else break;
            }
            if (!inst) return 'no-instance';
            const cs = ${content_state};
            const newState = window.Draftail.createEditorStateFromRaw(cs);
            if (!newState) return 'create-failed';
            inst.onChange(newState);
            if (inst.saveState) inst.saveState();
            return 'ok';
        })()
    " 2>/dev/null || echo "error")

    if [[ "$injected" != "ok" ]]; then
        echo "  [warn] Alumni injection returned '${injected}'" >&2
    fi
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
# Usage: add_quote_block "quote text" "attribution" ["image_search_term"]
# If image_search_term is provided AND the Quote block has an image field,
# we'll try to find and attach an image from the Wagtail media library.
add_quote_block() {
    local quotation="$1"
    local citation_name="${2:-}"
    local image_search="${3:-}"

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

        # Try to set the optional image field if a search term was provided
        if [[ -n "$image_search" ]]; then
            _try_quote_image "$block_sel" "$image_search"
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

# Internal: attempt to set an image on a Quote block's optional image field.
# Tries common field names (image, photo, portrait, headshot).
# Fails silently if no image field exists.
_try_quote_image() {
    local block_sel="$1"
    local search_term="$2"

    # Only attempt if image-helpers.sh is loaded
    if ! declare -f choose_image_for_field &>/dev/null; then
        echo "  [info] Image helpers not loaded, skipping quote image"
        return 0
    fi

    # Try common image field names
    for field_name in "image" "photo" "portrait" "headshot" "author_image"; do
        local field_exists
        field_exists=$(has_image_field "$block_sel" "$field_name")
        if [[ "$field_exists" == "yes" ]]; then
            echo "  Quote has image field: '${field_name}' — selecting image..."
            if choose_image_for_field "$block_sel" "$field_name" "$search_term"; then
                return 0
            else
                echo "  [warn] Could not set quote image, continuing without it" >&2
                return 0
            fi
        fi
    done

    echo "  [info] Quote block has no image field (or field not detected)"
}

# Add a Text with Image block (StructBlock with text + image + optional position)
# This block type creates a rich visual layout pairing body text with an image.
# Usage: add_text_with_image_block "body text" "image_search_term" ["left"|"right"]
add_text_with_image_block() {
    local text="$1"
    local image_search="$2"
    local image_position="${3:-}"  # left or right, if the block supports it

    # Try the exact block type name — discovery will confirm the real name.
    # Common names: "Text with image", "Image with text", "Text and image"
    local block_added="false"
    for block_name in "Text with image" "Image with text" "Text and image" "Text + Image"; do
        if streamfield_add_block "body" "$block_name" 2>/dev/null; then
            block_added="true"
            echo "  Text-with-image block added as: '${block_name}'"
            break
        fi
    done

    if [[ "$block_added" != "true" ]]; then
        echo "  [warn] No text-with-image block type found, falling back to Paragraph" >&2
        add_paragraph_block "$text"
        return 0
    fi

    local block_sel
    block_sel=$(streamfield_get_last_block "body")

    # Discover the block's fields dynamically
    local fields_json
    fields_json=$(list_block_fields "$block_sel" 2>/dev/null || echo "[]")
    echo "  Text-with-image fields: ${fields_json}"

    # Fill the text/body field (try common names)
    local text_filled="false"
    for field_name in "text" "body" "content" "paragraph" "description"; do
        local field_check
        field_check=$($RODNEY_CMD js "
            document.querySelector('${block_sel} [data-contentpath=\"${field_name}\"]') ? 'yes' : 'no'
        " 2>/dev/null || echo "no")

        if [[ "$field_check" == "yes" ]]; then
            # Check if it's a Draftail (rich text) field
            local is_draftail
            is_draftail=$($RODNEY_CMD js "
                document.querySelector('${block_sel} [data-contentpath=\"${field_name}\"] .Draftail-Editor') ? 'draftail' : 'plain'
            " 2>/dev/null || echo "plain")

            if [[ "$is_draftail" == "draftail" ]]; then
                draftail_set_content "${block_sel} [data-contentpath=\"${field_name}\"]" "$text"
            else
                streamfield_fill_field "$block_sel" "$field_name" "$text"
            fi
            text_filled="true"
            echo "  Text set via field: ${field_name}"
            break
        fi
    done

    if [[ "$text_filled" != "true" ]]; then
        echo "  [warn] Could not find text field in text-with-image block" >&2
    fi

    # Fill the image field
    if declare -f choose_image_for_field &>/dev/null; then
        for field_name in "image" "photo" "picture" "media"; do
            local img_exists
            img_exists=$(has_image_field "$block_sel" "$field_name")
            if [[ "$img_exists" == "yes" ]]; then
                choose_image_for_field "$block_sel" "$field_name" "$image_search" || true
                break
            fi
        done
    fi

    # Set image position if supported
    if [[ -n "$image_position" ]]; then
        for field_name in "image_position" "position" "alignment" "layout"; do
            local pos_check
            pos_check=$($RODNEY_CMD js "
                document.querySelector('${block_sel} [data-contentpath=\"${field_name}\"] select') ? 'yes' : 'no'
            " 2>/dev/null || echo "no")
            if [[ "$pos_check" == "yes" ]]; then
                $RODNEY_CMD js "
                    (() => {
                        const sel = document.querySelector('${block_sel} [data-contentpath=\"${field_name}\"] select');
                        if (!sel) return 'no-select';
                        // Try to find the option matching our desired position
                        for (const opt of sel.options) {
                            if (opt.value.toLowerCase().includes('${image_position}') ||
                                opt.textContent.toLowerCase().includes('${image_position}')) {
                                sel.value = opt.value;
                                sel.dispatchEvent(new Event('change', { bubbles: true }));
                                return 'set';
                            }
                        }
                        return 'option-not-found';
                    })()
                " 2>/dev/null || true
                echo "  Image position '${image_position}' set via field: ${field_name}"
                break
            fi
        done
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
