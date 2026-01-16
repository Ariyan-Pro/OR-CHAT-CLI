#!/usr/bin/env bash
# Configuration management for ORCHAT - FIXED VERSION
# Phase 7.5: Handle missing config files gracefully

CONFIG_DIR="${ORCHAT_CONFIG_DIR:-$HOME/.config/orchat}"
CONFIG_FILE="$CONFIG_DIR/config"
SCHEMA_FILE="$CONFIG_DIR/schema.json"

# Debug logging helper
_config_log() {
    local level="$1"
    local message="$2"
    if [[ "${ORCHAT_DEBUG:-}" == "1" ]]; then
        echo "[CONFIG:$level] $message" >&2
    fi
}

# Load configuration - SILENT VERSION
config_load() {
    if [[ -f "$CONFIG_FILE" ]] && [[ -r "$CONFIG_FILE" ]]; then
        _config_log "INFO" "Loading config from $CONFIG_FILE"
        
        local first_line
        first_line=$(head -n 1 "$CONFIG_FILE" 2>/dev/null || true)

        # Check if file contains just an API key (no = sign)
        if [[ "$first_line" =~ ^sk-or- ]] && [[ ! "$first_line" =~ = ]]; then
            # It's just an API key
            export OPENROUTER_API_KEY="$first_line"
            _config_log "INFO" "Loaded API key from $CONFIG_FILE"
            return 0
        else
            # It's a key=value config file
            while IFS='=' read -r key value || [[ -n "$key" ]]; do
                # Skip comments and empty lines
                [[ "$key" =~ ^# ]] && continue
                [[ -z "$key" ]] && continue

                # Remove quotes from value
                value="${value%\"}"
                value="${value#\"}"
                value="${value%\'}"
                value="${value#\'}"

                # Trim whitespace
                key=$(echo "$key" | xargs)
                value=$(echo "$value" | xargs)

                # Export variable
                local var_name="ORCHAT_$(echo "$key" | tr '[:lower:]' '[:upper:]')"
                export "$var_name"="$value"
                _config_log "DEBUG" "Set $var_name=$value"
            done < "$CONFIG_FILE"
            return 0
        fi
    else
        # No config file - this is OK for validation
        _config_log "DEBUG" "No config file found at $CONFIG_FILE (this is normal)"
        return 0
    fi
}

# Get config value
config_get() {
    local key="$1"
    local default="${2:-}"
    local var_name="ORCHAT_$(echo "$key" | tr '[:lower:]' '[:upper:]')"
    
    if [[ -n "${!var_name:-}" ]]; then
        echo "${!var_name}"
    else
        echo "$default"
    fi
}

# Set config value
config_set() {
    local key="$1"
    local value="$2"
    
    mkdir -p "$CONFIG_DIR"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Update existing key or add new
        if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null; then
            sed -i "s/^[[:space:]]*${key}[[:space:]]*=.*/${key} = ${value}/" "$CONFIG_FILE"
        else
            echo "${key} = ${value}" >> "$CONFIG_FILE"
        fi
    else
        echo "${key} = ${value}" > "$CONFIG_FILE"
    fi
    
    chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    export "ORCHAT_$(echo "$key" | tr '[:lower:]' '[:upper:]')"="$value"
    _config_log "INFO" "Set $key = $value"
}

# Show configuration
config_show() {
    if [[ -f "$CONFIG_FILE" ]] && [[ -r "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo "# ORCHAT Configuration"
        echo "# No configuration file found at $CONFIG_FILE"
        echo "#"
        echo "# To set API key:"
        echo "# orchat config set api.openrouter_api_key 'your-key-here'"
    fi
}

# Initialize - always succeed
config_init() {
    config_load
    return 0
}

# Main execution (if script is run directly)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        load) config_load ;;
        get) config_get "$2" "$3" ;;
        set) config_set "$2" "$3" ;;
        show) config_show ;;
        init) config_init ;;
        *) 
            echo "Usage: $0 {load|get|set|show|init}"
            exit 1
            ;;
    esac
else
    # Being sourced - initialize silently
    config_init >/dev/null 2>&1 || true
fi
