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

# Convert text to Draft.js ContentState JSON with a specific heading level (h3, h4, etc.)
# Usage: heading_to_contentstate "Subhead text" "header-three"
heading_to_contentstate() {
    local text="$1"
    local block_type="${2:-header-three}"

    python3 -c "
import json, sys, hashlib

text = sys.argv[1]
block_type = sys.argv[2]

key = hashlib.md5(b'heading0').hexdigest()[:5]
blocks = [{
    'key': key,
    'text': text.strip(),
    'type': block_type,
    'depth': 0,
    'inlineStyleRanges': [],
    'entityRanges': [],
    'data': {}
}]

content_state = {'blocks': blocks, 'entityMap': {}}
print(json.dumps(content_state))
" "$text" "$block_type"
}

# Convert a list of alumni stories (name + URL pairs) to Draft.js ContentState with links
# Input: JSON array string, e.g. '[{"name":"...", "url":"..."},...]'
# Output: ContentState JSON with each alumni as a linked paragraph
alumni_to_contentstate() {
    local alumni_json="$1"

    python3 -c "
import json, sys, hashlib

alumni = json.loads(sys.argv[1])
blocks = []
entity_map = {}
entity_key = 0

for i, alum in enumerate(alumni):
    name = alum.get('name', '')
    url = alum.get('url', '')
    key = hashlib.md5(f'alumni{i}'.encode()).hexdigest()[:5]

    entity_ranges = []
    if url:
        entity_map[str(entity_key)] = {
            'type': 'LINK',
            'mutability': 'MUTABLE',
            'data': {'url': url}
        }
        entity_ranges.append({
            'offset': 0,
            'length': len(name),
            'key': entity_key
        })
        entity_key += 1

    blocks.append({
        'key': key,
        'text': name,
        'type': 'unstyled',
        'depth': 0,
        'inlineStyleRanges': [],
        'entityRanges': entity_ranges,
        'data': {}
    })

content_state = {'blocks': blocks, 'entityMap': entity_map}
print(json.dumps(content_state))
" "$alumni_json"
}

# Inject content into a Draftail rich text editor via React component internals.
# This properly updates the Draft.js EditorState so content persists on form save.
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

    # Strategy A: Set via React component onChange + Draftail.createEditorStateFromRaw
    local injected
    injected=$($RODNEY_CMD js "
        (() => {
            const container = document.querySelector('${container_selector}');
            if (!container) return 'no-container';

            const editorEl = container.querySelector('.Draftail-Editor');
            if (!editorEl) return 'no-editor';

            // Find React fiber key dynamically
            const fiberKey = Object.keys(editorEl).find(k => k.indexOf('reactInternalInstance') > -1 || k.indexOf('reactFiber') > -1);
            if (!fiberKey) return 'no-fiber';

            // Traverse up to find the DraftailEditor component instance
            let node = editorEl[fiberKey];
            let inst = null;
            for (let i = 0; i < 20; i++) {
                if (node && node.stateNode && node.stateNode.onChange) {
                    inst = node.stateNode;
                    break;
                }
                if (node) node = node.return;
                else break;
            }
            if (!inst) return 'no-instance';

            // Create EditorState from raw ContentState and apply it
            const cs = ${content_state};
            const newState = window.Draftail.createEditorStateFromRaw(cs);
            if (!newState) return 'create-failed';

            inst.onChange(newState);
            if (inst.saveState) inst.saveState();
            return 'ok';
        })()
    " 2>/dev/null || echo "error")

    case "$injected" in
        ok)
            echo "  Draftail content set via React EditorState."
            return 0
            ;;
        no-container)
            echo "  [warn] Container '${container_selector}' not found. Trying fallback..." >&2
            ;;
        no-editor)
            echo "  [warn] Draftail editor not found in '${container_selector}'. Trying fallback..." >&2
            ;;
        no-fiber|no-instance)
            echo "  [warn] React internals not accessible (${injected}). Trying fallback..." >&2
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
# Uses React component internals to ensure content persists on save.
draftail_set_raw_contentstate() {
    local container_selector="$1"
    local json_string="$2"

    $RODNEY_CMD js "
        (() => {
            const container = document.querySelector('${container_selector}');
            if (!container) return 'no-container';
            const editorEl = container.querySelector('.Draftail-Editor');
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
            const cs = ${json_string};
            const newState = window.Draftail.createEditorStateFromRaw(cs);
            if (!newState) return 'create-failed';
            inst.onChange(newState);
            if (inst.saveState) inst.saveState();
            return 'ok';
        })()
    "
}
