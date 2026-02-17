#!/usr/bin/env bash
# lib/draftail.sh -- Draftail rich text editor interaction helpers
# Source after config/env.sh, config/selectors.sh, and lib/rodney-helpers.sh
#
# Strategy A (preferred): Inject Draft.js ContentState JSON into the hidden input.
# Strategy B (fallback): Click the contenteditable div and type.

# Convert plain text (with \n paragraph breaks) to Draft.js ContentState JSON
# Usage: text_to_contentstate "First paragraph.\nSecond paragraph."
text_to_contentstate() {
    local text="$1"

    # Split text by double newlines into paragraphs, build ContentState blocks
    python3 -c "
import json, sys, hashlib

text = sys.argv[1]
paragraphs = [p.strip() for p in text.split('\n\n') if p.strip()]
if not paragraphs:
    paragraphs = [p.strip() for p in text.split('\n') if p.strip()]

blocks = []
for i, para in enumerate(paragraphs):
    key = hashlib.md5(f'block{i}'.encode()).hexdigest()[:5]
    blocks.append({
        'key': key,
        'text': para,
        'type': 'unstyled',
        'depth': 0,
        'inlineStyleRanges': [],
        'entityRanges': [],
        'data': {}
    })

content_state = {'blocks': blocks, 'entityMap': {}}
print(json.dumps(content_state))
" "$text"
}

# Inject content into a Draftail rich text editor via its hidden input
# Usage: draftail_set_content "[data-contentpath='body']" "Text content here"
draftail_set_content() {
    local container_selector="$1"
    local text="$2"

    echo "  Setting Draftail content in ${container_selector}..."

    # Build the ContentState JSON
    local content_state
    content_state=$(text_to_contentstate "$text")

    if [[ -z "$content_state" ]] || [[ "$content_state" == "null" ]]; then
        echo "  [error] Failed to build ContentState JSON." >&2
        return 1
    fi

    # Strategy A: Inject via hidden input
    local injected
    injected=$($RODNEY_CMD js "
        (() => {
            const container = document.querySelector('${container_selector}');
            if (!container) return 'no-container';

            // Find the hidden input (Draftail stores its state here)
            const input = container.querySelector('input[type=\"hidden\"]')
                       || container.querySelector('textarea[data-draftail-input]')
                       || container.querySelector('textarea');
            if (!input) return 'no-input';

            // Set the value to our ContentState JSON
            const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
                window.HTMLInputElement.prototype, 'value'
            )?.set || Object.getOwnPropertyDescriptor(
                window.HTMLTextAreaElement.prototype, 'value'
            )?.set;

            if (nativeInputValueSetter) {
                nativeInputValueSetter.call(input, JSON.stringify(${content_state}));
            } else {
                input.value = JSON.stringify(${content_state});
            }

            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return 'ok';
        })()
    " 2>/dev/null || echo "error")

    case "$injected" in
        ok)
            echo "  Draftail content injected via hidden input."
            return 0
            ;;
        no-container)
            echo "  [warn] Container '${container_selector}' not found. Trying fallback..." >&2
            ;;
        no-input)
            echo "  [warn] Hidden input not found in '${container_selector}'. Trying fallback..." >&2
            ;;
        *)
            echo "  [warn] Injection returned '${injected}'. Trying fallback..." >&2
            ;;
    esac

    # Strategy B: Click and type into the contenteditable div
    draftail_type_content "$container_selector" "$text"
}

# Fallback: type content directly into the Draftail contenteditable area
draftail_type_content() {
    local container_selector="$1"
    local text="$2"

    echo "  Typing content into Draftail editor (fallback)..."

    local editor_selector="${container_selector} .public-DraftEditor-content"
    if ! element_exists "$editor_selector"; then
        editor_selector="${container_selector} [contenteditable=\"true\"]"
    fi

    if ! element_exists "$editor_selector"; then
        echo "  [error] No contenteditable element found in ${container_selector}." >&2
        take_named_screenshot "error-draftail-no-editor"
        return 1
    fi

    # Click to focus the editor
    rodney_cmd click "$editor_selector"
    sleep 0.5

    # Type the text (loses formatting but gets content in)
    # Replace newlines with Enter key presses via JS
    $RODNEY_CMD js "
        (() => {
            const editor = document.querySelector('${editor_selector}');
            editor.focus();
            const text = $(printf '%s' "$text" | jq -Rs .);
            const paragraphs = text.split('\n\n').filter(p => p.trim());
            paragraphs.forEach((para, i) => {
                document.execCommand('insertText', false, para);
                if (i < paragraphs.length - 1) {
                    document.execCommand('insertParagraph', false);
                }
            });
        })()
    "

    echo "  Content typed into Draftail editor."
}

# Set Draftail content from a raw ContentState JSON string (pre-built)
draftail_set_raw_contentstate() {
    local container_selector="$1"
    local json_string="$2"

    $RODNEY_CMD js "
        (() => {
            const container = document.querySelector('${container_selector}');
            if (!container) return 'no-container';
            const input = container.querySelector('input[type=\"hidden\"]')
                       || container.querySelector('textarea');
            if (!input) return 'no-input';
            input.value = ${json_string};
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return 'ok';
        })()
    "
}
