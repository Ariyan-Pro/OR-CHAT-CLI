#!/usr/bin/env bash
# Parse orchat.toml for Gemini CLI integration

GEMINI_CONFIG="${ORCHAT_CONFIG_DIR:-$HOME/.config/orchat}/orchat.toml"

gemini_load_config() {
    if [[ ! -f "$GEMINI_CONFIG" ]]; then
        # Create default config
        mkdir -p "$(dirname "$GEMINI_CONFIG")"
        cat > "$GEMINI_CONFIG" << 'TOML'
[orchat]
binary = "orchat"
supports_streaming = true
supports_multiturn = true
description = "OpenRouter CLI with advanced features"

[defaults]
model = "openai/gpt-3.5-turbo"
temperature = 0.7
max_context_length = 4000

[features]
api_key_management = true
model_browser = true
session_persistence = true
TOML
    fi
    
    # Parse with Python (toml support)
    python3 -c "
try:
    import toml
    config = toml.load('$GEMINI_CONFIG')
    print('ORCHAT_CONFIG_LOADED=1')
    
    # Export as environment variables
    for section, values in config.items():
        if isinstance(values, dict):
            for key, value in values.items():
                if isinstance(value, (str, int, float, bool)):
                    var_name = f\"ORCHAT_{section.upper()}_{key.upper()}\"
                    print(f'{var_name}=\"{value}\"')
except ImportError:
    # Fallback to simple grep for basic values
    import re
    with open('$GEMINI_CONFIG', 'r') as f:
        content = f.read()
    
    # Extract simple key-value pairs
    for line in content.split('\\n'):
        line = line.strip()
        if '=' in line and not line.startswith('[') and not line.startswith('#'):
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip().strip('\"\\'')
            if key and value:
                print(f'ORCHAT_{key.upper()}=\"{value}\"')
" 2>/dev/null | while read -r line; do
        export "$line"
    done
}

gemini_validate_config() {
    if [[ ! -f "$GEMINI_CONFIG" ]]; then
        return 0  # No config is valid
    fi
    
    python3 -c "
import json, sys
schema = {
    'type': 'object',
    'properties': {
        'orchat': {'type': 'object'},
        'defaults': {'type': 'object'},
        'features': {'type': 'object'}
    },
    'additionalProperties': False
}

# Simple validation - just check if it's parseable
try:
    import toml
    with open('$GEMINI_CONFIG', 'r') as f:
        config = toml.load(f)
    print('VALID_CONFIG=1')
except Exception as e:
    print(f'INVALID_CONFIG: {e}')
    sys.exit(1)
" 2>/dev/null && return 0 || return 1
}

gemini_generate_spec() {
    cat << 'SPEC'
{
  "name": "orchat",
  "version": "0.3.0",
  "description": "OpenRouter CLI with advanced AI features",
  "binary": "orchat",
  "capabilities": ["chat", "streaming", "multi-turn", "model-selection"],
  "config_file": "~/.config/orchat/orchat.toml",
  "environment_variables": ["OPENROUTER_API_KEY"],
  "required_dependencies": ["curl", "jq", "python3"],
  "optional_dependencies": ["rlwrap", "python3-toml"]
}
SPEC
}