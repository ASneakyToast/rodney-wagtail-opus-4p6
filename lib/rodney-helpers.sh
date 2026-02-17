#!/usr/bin/env bash
# lib/rodney-helpers.sh -- Reusable Rodney wrapper functions
# Source this file in scripts: source "$(dirname "$0")/../lib/rodney-helpers.sh"

# Requires RODNEY_CMD and SCREENSHOT_DIR from config/env.sh

# Run a rodney command with logging
rodney_cmd() {
    local cmd_desc="$*"
    echo "  [rodney] $cmd_desc"
    $RODNEY_CMD "$@"
}

# Retry a rodney command up to N times with exponential backoff
rodney_retry() {
    local max_attempts="${1:-3}"
    shift
    local delay=2

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        if $RODNEY_CMD "$@"; then
            return 0
        fi
        if ((attempt < max_attempts)); then
            echo "  [retry] Attempt $attempt/$max_attempts failed, waiting ${delay}s..." >&2
            $RODNEY_CMD sleep "$delay" 2>/dev/null || sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    echo "  [error] Command failed after $max_attempts attempts: rodney $*" >&2
    take_named_screenshot "error-retry-exhausted"
    return 1
}

# Wait for a selector, then click it
rodney_wait_and_click() {
    local selector="$1"
    rodney_cmd wait "$selector"
    rodney_cmd waitstable
    rodney_cmd click "$selector"
}

# Clear a field, input text, and verify the value took
rodney_safe_input() {
    local selector="$1"
    local text="$2"

    rodney_cmd wait "$selector"
    rodney_cmd clear "$selector"
    rodney_cmd input "$selector" "$text"

    # Verify the value was set correctly
    local actual
    actual=$($RODNEY_CMD js "document.querySelector('${selector}').value")
    if [[ "$actual" != "$text" ]]; then
        echo "  [warn] Field $selector: expected '${text:0:40}...' but got '${actual:0:40}...'" >&2
        # Retry once: clear and re-input
        rodney_cmd clear "$selector"
        rodney_cmd input "$selector" "$text"
    fi
}

# Take a screenshot with a descriptive name
take_named_screenshot() {
    local step_name="$1"
    local filename="${SCREENSHOT_DIR}/$(date +%Y%m%d-%H%M%S)-${step_name}.png"
    $RODNEY_CMD screenshot "$filename"
    echo "  [screenshot] $filename"
    echo "$filename"
}

# Start rodney if not already running
ensure_browser() {
    if $RODNEY_CMD status &>/dev/null; then
        echo "  [rodney] Browser already running."
    else
        echo "  [rodney] Starting browser..."
        if [[ "${RODNEY_LOCAL:-false}" == "true" ]]; then
            $RODNEY_CMD start --local
        else
            $RODNEY_CMD start
        fi
        sleep 2
    fi
}

# Assert current URL contains a substring
check_url_contains() {
    local expected="$1"
    local current_url
    current_url=$($RODNEY_CMD url)
    if [[ "$current_url" != *"$expected"* ]]; then
        echo "  [error] Expected URL to contain '$expected', but at: $current_url" >&2
        take_named_screenshot "error-wrong-url"
        return 1
    fi
}

# Wait for page to fully settle (load + DOM stable + network idle)
wait_for_page() {
    $RODNEY_CMD waitload 2>/dev/null || true
    $RODNEY_CMD waitstable
    $RODNEY_CMD waitidle 2>/dev/null || true
}

# Extract text content, returning empty string on failure instead of erroring
safe_text() {
    local selector="$1"
    $RODNEY_CMD text "$selector" 2>/dev/null || echo ""
}

# Check if element exists (returns 0/1 exit code)
element_exists() {
    local selector="$1"
    $RODNEY_CMD exists "$selector" 2>/dev/null
}
