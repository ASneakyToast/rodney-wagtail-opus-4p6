#!/usr/bin/env bash
# config/env.sh -- Load environment variables and validate required config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if it exists
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Defaults
export SCREENSHOT_DIR="${SCREENSHOT_DIR:-$PROJECT_ROOT/screenshots}"
export RODNEY_LOCAL="${RODNEY_LOCAL:-true}"

# Ensure screenshot directory exists
mkdir -p "$SCREENSHOT_DIR"

# Validation helper
require_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    if [[ -z "$var_value" ]]; then
        echo "ERROR: Required environment variable $var_name is not set." >&2
        echo "Copy .env.example to .env and fill in your values." >&2
        exit 2
    fi
}

# Validate required variables
require_var WAGTAIL_ADMIN_URL
require_var WAGTAIL_USERNAME
require_var WAGTAIL_PASSWORD
require_var PARENT_PAGE_ID
require_var PAGE_TYPE_APP_LABEL
require_var PAGE_TYPE_MODEL

# Strip trailing slash from admin URL for consistent path building
export WAGTAIL_ADMIN_URL="${WAGTAIL_ADMIN_URL%/}"

# Check dependencies
for cmd in jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command '$cmd' not found. Please install it." >&2
        exit 2
    fi
done

# Check that rodney is available (via uvx or direct)
if ! command -v rodney &>/dev/null && ! command -v uvx &>/dev/null; then
    echo "ERROR: Neither 'rodney' nor 'uvx' found. Install rodney or uv." >&2
    exit 2
fi

# Wrapper: use rodney directly if available, otherwise uvx
RODNEY_CMD="${RODNEY_CMD:-}"
if [[ -z "$RODNEY_CMD" ]]; then
    if command -v rodney &>/dev/null; then
        RODNEY_CMD="rodney"
    else
        RODNEY_CMD="uvx rodney"
    fi
fi
export RODNEY_CMD

echo "Config loaded: ${WAGTAIL_ADMIN_URL} (user: ${WAGTAIL_USERNAME})"
