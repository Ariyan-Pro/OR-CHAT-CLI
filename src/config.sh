#!/usr/bin/env bash
# Configuration management for ORCHAT - SECURITY HARDENED VERSION
# Phase 8: Comprehensive security fixes

CONFIG_DIR="${ORCHAT_CONFIG_DIR:-$HOME/.config/orchat}"
CONFIG_FILE="$CONFIG_DIR/config"
SCHEMA_FILE="$CONFIG_DIR/schema.json"

# Security: Allowed config keys whitelist (strict)
ALLOWED_CONFIG_KEYS="api.openrouter_api_key api.model api.temperature api.max_tokens api.timeout behavior.stream behavior.verbose paths.data paths.logs"

# Security: Check if a key is in the whitelist
_config_key_allowed() {
    local key="$1"
    local allowed_key
    
    for allowed_key in $ALLOWED_CONFIG_KEYS; do
        if [[ "$key" == "$allowed_key" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Debug logging helper
_config_log() {
    local level="$1"
    local message="$2"
    if [[ "${ORCHAT_DEBUG:-}" == "1" ]]; then
        echo "[CONFIG:$level] $message" >&2
    fi
}

# Security: Validate config key against whitelist
_config_validate_key() {
    local key="$1"
    
    # Check for empty key
    if [[ -z "$key" ]]; then
        _config_log "ERROR" "Empty config key rejected"
        return 1
    fi
    
    # Check for path traversal attempts
    if [[ "$key" =~ \.\. ]] || [[ "$key" =~ ^/ ]] || [[ "$key" =~ \\\\. ]]; then
        _config_log "ERROR" "Path traversal attempt in key rejected: $key"
        return 1
    fi
    
    # Check for command injection patterns
    if [[ "$key" =~ [\$\`] ]] || [[ "$key" =~ \( ]] || [[ "$key" =~ \| ]] || [[ "$key" =~ \; ]] || [[ "$key" =~ \& ]]; then
        _config_log "ERROR" "Command injection attempt in key rejected: $key"
        return 1
    fi
    
    # Check against allowed keys pattern (if whitelist is enforced)
    if ! echo "$key" | grep -qE "^[a-zA-Z0-9._-]+$"; then
        _config_log "ERROR" "Invalid characters in config key: $key"
        return 1
    fi
    
    
    # CRITICAL FIX C-002: Enforce strict whitelist of allowed config keys
    if ! _config_key_allowed "$key"; then
        _config_log "ERROR" "Config key not in whitelist: $key"
        return 1
    fi
    return 0
}

# Security: Sanitize config value
_config_sanitize_value() {
    local value="$1"
    
    # Remove any potential command injection patterns
    value="${value//\$/}"
    value="${value//\`/}"
    value="${value//;/}"
    value="${value//|/}"
    value="${value//&/}"
    
    # Limit value length to prevent buffer issues
    if [[ ${#value} -gt 4096 ]]; then
        _config_log "WARN" "Config value truncated to 4096 chars"
        value="${value:0:4096}"
    fi
    
    echo "$value"
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
    # Convert dots to underscores for valid bash variable names
    local var_name="ORCHAT_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
    
    if [[ -n "${!var_name:-}" ]]; then
        echo "${!var_name}"
    else
        echo "$default"
    fi
}

# Set config value - SECURITY HARDENED
config_set() {
    local key="$1"
    local value="$2"
    
    # Security: Validate the key
    if ! _config_validate_key "$key"; then
        echo "[ERROR] Invalid configuration key rejected" >&2
        return 1
    fi
    
    # Security: Sanitize the value
    value=$(_config_sanitize_value "$value")
    
    mkdir -p "$CONFIG_DIR"
    
    # Security: Escape special characters for sed
    local escaped_key
    escaped_key=$(printf '%s\n' "$key" | sed 's/[]\/$*.^[]/\\&/g')
    local escaped_value
    escaped_value=$(printf '%s\n' "$value" | sed "s/['\"]/\\\\&/g")
    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Update existing key or add new
        if grep -q "^[[:space:]]*${escaped_key}[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null; then
            sed -i "s/^[[:space:]]*${escaped_key}[[:space:]]*=.*/${key} = ${escaped_value}/" "$CONFIG_FILE"
        else
            echo "${key} = ${escaped_value}" >> "$CONFIG_FILE"
        fi
    else
        echo "${key} = ${escaped_value}" > "$CONFIG_FILE"
    fi
    
    chmod 600 "$CONFIG_FILE" 2>/dev/null || true
    # Convert dots to underscores for valid bash variable names
    local var_name="ORCHAT_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
    export "$var_name"="$value"
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

# Handle config subcommands (get, set, list)
config_handle() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        get)
            local key="${2:-}"
            if [[ -z "$key" ]]; then
                echo "[ERROR] Usage: orchat config get <key>" >&2
                return ${E_CONFIG_MISSING:-16}
            fi
            config_get "$key"
            ;;
        set)
            local key="${2:-}"
            local value="${3:-}"
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                echo "[ERROR] Usage: orchat config set <key> <value>" >&2
                return ${E_CONFIG_INVALID:-17}
            fi
            config_set "$key" "$value"
            echo "Configuration updated: $key = $value"
            ;;
        list)
            config_show
            ;;
        *)
            echo "Usage: orchat config <get|set|list>" >&2
            echo "  get <key>     - Get a configuration value" >&2
            echo "  set <key> <value> - Set a configuration value" >&2
            echo "  list          - List all configuration" >&2
            return ${E_CONFIG_INVALID:-17}
            ;;
    esac
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
            exit ${E_CONFIG_INVALID:-17}
            ;;
    esac
else
    # Being sourced - initialize silently
    config_init >/dev/null 2>&1 || true
fi
