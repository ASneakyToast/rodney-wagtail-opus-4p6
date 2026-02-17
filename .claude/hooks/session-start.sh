#!/bin/bash
set -euo pipefail

# Only run in Claude Code on the web (remote containers)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# -------------------------------------------------------
# Install system dependencies
# -------------------------------------------------------

# jq — required by config/env.sh
if ! command -v jq &>/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq jq
fi

# Google Chrome — required by Rodney (drives Chrome via DevTools Protocol)
if ! command -v google-chrome &>/dev/null && ! command -v chromium-browser &>/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq wget gnupg
  wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq google-chrome-stable
fi

# -------------------------------------------------------
# Install uv (provides uvx for running rodney/showboat)
# -------------------------------------------------------

if ! command -v uvx &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Make uv/uvx available in this session and future Bash calls
  export PATH="$HOME/.local/bin:$PATH"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
  fi
fi

# -------------------------------------------------------
# Pre-warm rodney and showboat so first uvx invocation is fast
# -------------------------------------------------------

uvx rodney --help >/dev/null 2>&1 || true
uvx showboat --help >/dev/null 2>&1 || true

# -------------------------------------------------------
# Configure environment for headless Chrome in containers
# -------------------------------------------------------

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export RODNEY_LOCAL=false' >> "$CLAUDE_ENV_FILE"
fi

echo "Session start hook complete: jq, Chrome, uv, rodney, showboat ready."
