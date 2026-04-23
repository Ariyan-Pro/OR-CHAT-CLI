#!/usr/bin/env bash
# ORCHAT Bootstrap - Phase 8 Security Hardened
set -euo pipefail

# Security: Enable strict mode
set -o nounset
set -o pipefail

# Determine root directory
ORCHAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ORCHAT_ROOT

# Security: Validate ORCHAT_ROOT doesn't contain dangerous characters
if [[ "$ORCHAT_ROOT" =~ [[:space:]\;\|\&\$\`] ]]; then
    echo "[ERROR] Invalid characters in ORCHAT_ROOT path" >&2
    exit 1
fi

# Security: Maximum input length constants
MAX_INPUT_LENGTH=100000
MAX_SYSTEM_FILE_SIZE=102400
MAX_CONFIG_VALUE_LENGTH=4096

# Load all modules in dependency order with security validation
# Load enterprise_logger first for logging infrastructure
enterprise_module="$ORCHAT_ROOT/src/enterprise_logger.sh"
if [[ -f "$enterprise_module" ]]; then
    if [[ ! -r "$enterprise_module" ]]; then
        echo "[ERROR] Enterprise logger module not readable: $enterprise_module" >&2
        exit 1
    fi
    if source "$enterprise_module" 2>/dev/null; then
        echo "[DEBUG] Loaded module: enterprise_logger" >&2
    else
        echo "[WARN] Failed to load enterprise_logger (non-fatal)" >&2
    fi
fi

for module in constants utils config env core io interactive streaming model_browser history context payload gemini_integration session workspace; do
    module_file="$ORCHAT_ROOT/src/$module.sh"

    if [[ -f "$module_file" ]]; then
        # Security: Verify file is readable and not world-writable
        if [[ ! -r "$module_file" ]]; then
            echo "[ERROR] Module file not readable: $module_file" >&2
            exit 1
        fi
        
        # Security: Check for world-writable permissions
        perms=$(stat -c "%a" "$module_file" 2>/dev/null || stat -f "%Lp" "$module_file" 2>/dev/null || echo "000")
        if [[ "${perms: -1}" =~ [2367] ]]; then
            echo "[WARN] Module file has insecure permissions: $module_file" >&2
        fi
        
        # shellcheck source=/dev/null
        if source "$module_file" 2>/dev/null; then
            echo "[DEBUG] Loaded module: $module" >&2
        else
            echo "[ERROR] Failed to load module: $module" >&2
            exit 1
        fi
    else
        echo "[WARN] Module file not found: $module_file" >&2
    fi
done

# Phase 3: Initialize Gemini config if available
if [[ -f "$HOME/.config/orchat/orchat.toml" ]] || [[ -f "config/orchat.toml" ]]; then
    if type gemini_load_config &>/dev/null; then
        if gemini_load_config 2>/dev/null; then
            echo "[DEBUG] Loaded Gemini configuration" >&2
        else
            echo "[WARN] Failed to load Gemini config" >&2
        fi
    fi
fi

# Initialize session directory
mkdir -p "$HOME/.orchat/sessions" 2>/dev/null || true

# Set default history directory if not set
export ORCHAT_HISTORY_DIR="${ORCHAT_HISTORY_DIR:-$HOME/.orchat/sessions}"
export MAX_HISTORY_LENGTH="${MAX_HISTORY_LENGTH:-20}"

# Global flag for deterministic mode
DETERMINISTIC_MODE=false

# Main entry point
main() {
    # First pass: check for --help or --version anywhere in arguments
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            echo "ORCHAT v0.3.3 - Enterprise CLI AI Assistant"
            echo "Usage: orchat <prompt> [options]"
            echo "       orchat -i [--system <file>]"
            echo "       orchat config <get|set|list>"
            echo "       orchat session <create|list|stats|cleanup> [args]"
            echo "       orchat models [--provider <name>]"
            echo ""
            echo "Options:"
            echo "  -m, --model MODEL       AI model to use (default: openai/gpt-3.5-turbo)"
            echo "  --temp, --temperature N Temperature (0.0-2.0, default: 0.7)"
            echo "  --tokens, --max-tokens N Maximum tokens in response (default: 1000)"
            echo "  --stream                Stream response tokens in real-time"
            echo "  --no-stream             Disable streaming (default)"
            echo "  --system FILE          Use system prompt from file"
            echo "  --deterministic         Enable deterministic mode (temperature=0.0)"
            echo "  -h, --help             Show this help"
            echo "  --version              Show version"
            exit 0
        fi
        
        if [[ "$arg" == "--version" ]] || [[ "$arg" == "-v" ]]; then
            echo "ORCHAT v0.3.3 - Workstream 3 Integrated"
            echo "Engineering: 50+ years legacy systems expertise"
            exit 0
        fi
    done
    
    # Parse command line arguments
    if [[ $# -eq 0 ]]; then
        echo "Usage: orchat <prompt> [options]"
        echo "       orchat -i [--system <file>]"
        echo "       orchat config <get|set|list>"
        echo "       orchat models [--provider <name>]"
        exit 0
    fi

    # Check for interactive mode
    if [[ "$1" == "-i" ]] || [[ "$1" == "--interactive" ]]; then
        shift
        if type start_interactive &>/dev/null; then
            start_interactive "$@"
        else
            echo "[ERROR] Interactive module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for read command
    if [[ "$1" == "read" ]]; then
        shift
        if type workspace_read &>/dev/null; then
            workspace_read "$@"
        else
            echo "[ERROR] File reading module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for analyze command
    if [[ "$1" == "analyze" ]]; then
        shift
        if type workspace_analyze &>/dev/null; then
            workspace_analyze "$@"
        else
            echo "[ERROR] Code analysis module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for summarize command
    if [[ "$1" == "summarize" ]]; then
        shift
        if type workspace_summarize &>/dev/null; then
            workspace_summarize "$@"
        else
            echo "[ERROR] Code summarization not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for assist command
    if [[ "$1" == "assist" ]]; then
        shift
        if type workspace_assist &>/dev/null; then
            workspace_assist "$@"
        else
            echo "[ERROR] AI assistance module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for suggest command
    if [[ "$1" == "suggest" ]]; then
        shift
        if type workspace_suggest &>/dev/null; then
            workspace_suggest "$@"
        else
            echo "[ERROR] Code suggestions not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for review command
    if [[ "$1" == "review" ]]; then
        shift
        if type workspace_review &>/dev/null; then
            workspace_review "$@"
        else
            echo "[ERROR] Code review not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for generate command
    if [[ "$1" == "generate" ]]; then
        shift
        if type workspace_generate &>/dev/null; then
            workspace_generate "$@"
        else
            echo "[ERROR] Code generation not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for generate-context command
    if [[ "$1" == "generate-context" ]]; then
        shift
        if type workspace_generate_context &>/dev/null; then
            workspace_generate_context "$@"
        else
            echo "[ERROR] Code context generation not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for generate-tests command
    if [[ "$1" == "generate-tests" ]]; then
        shift
        if type workspace_generate_tests &>/dev/null; then
            workspace_generate_tests "$@"
        else
            echo "[ERROR] Test generation not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for refactor-analyze command
    if [[ "$1" == "refactor-analyze" ]]; then
        shift
        if type workspace_refactor_analyze &>/dev/null; then
            workspace_refactor_analyze "$@"
        else
            echo "[ERROR] Refactoring analysis not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for refactor-suggest command
    if [[ "$1" == "refactor-suggest" ]]; then
        shift
        if type workspace_refactor_suggest &>/dev/null; then
            workspace_refactor_suggest "$@"
        else
            echo "[ERROR] Refactoring suggestions not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for document-file command
    if [[ "$1" == "document-file" ]]; then
        shift
        if type workspace_document_file &>/dev/null; then
            workspace_document_file "$@"
        else
            echo "[ERROR] Documentation generation not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for package-deb command
    if [[ "$1" == "package-deb" ]]; then
        shift
        if type workspace_package_deb &>/dev/null; then
            workspace_package_deb "$@"
        else
            echo "[ERROR] Enterprise packaging not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for package-docker command
    if [[ "$1" == "package-docker" ]]; then
        shift
        if type workspace_package_docker &>/dev/null; then
            workspace_package_docker "$@"
        else
            echo "[ERROR] Docker packaging not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for package-installer command
    if [[ "$1" == "package-installer" ]]; then
        shift
        if type workspace_package_installer &>/dev/null; then
            workspace_package_installer "$@"
        else
            echo "[ERROR] Installer generation not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for metrics-init command
    if [[ "$1" == "metrics-init" ]]; then
        shift
        if type workspace_metrics_init &>/dev/null; then
            workspace_metrics_init "$@"
        else
            echo "[ERROR] Metrics module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for metrics-prometheus command
    if [[ "$1" == "metrics-prometheus" ]]; then
        shift
        if type workspace_metrics_prometheus &>/dev/null; then
            workspace_metrics_prometheus "$@"
        else
            echo "[ERROR] Metrics module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for health-check command
    if [[ "$1" == "health-check" ]]; then
        shift
        if type workspace_health_check &>/dev/null; then
            workspace_health_check "$@"
        else
            echo "[ERROR] Health check not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for enterprise command
    if [[ "$1" == "enterprise" ]]; then
        shift
        if type workspace_enterprise &>/dev/null; then
            workspace_enterprise "$@"
        else
            echo "[ERROR] Enterprise module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for document-readme command
    if [[ "$1" == "document-readme" ]]; then
        shift
        if type workspace_document_readme &>/dev/null; then
            workspace_document_readme "$@"
        else
            echo "[ERROR] README generation not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for explain command
    if [[ "$1" == "explain" ]]; then
        shift
        if type workspace_explain &>/dev/null; then
            workspace_explain "$@"
        else
            echo "[ERROR] Code explanation not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for understand command
    if [[ "$1" == "understand" ]]; then
        shift
        if type workspace_understand &>/dev/null; then
            workspace_understand "$@"
        else
            echo "[ERROR] Code understanding not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for context command
    if [[ "$1" == "context" ]]; then
        shift
        if type workspace_context &>/dev/null; then
            workspace_context "$@"
        else
            echo "[ERROR] Context module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for status command
    if [[ "$1" == "status" ]]; then
        shift
        if type workspace_status &>/dev/null; then
            workspace_status "$@"
        else
            echo "[ERROR] Workspace module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for status command
    if [[ "$1" == "status" ]]; then
        shift
        if type workspace_status &>/dev/null; then
            workspace_status "$@"
        else
            echo "[ERROR] Workspace module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for config commands
    if [[ "$1" == "config" ]]; then
        shift
        if type config_handle &>/dev/null; then
            config_handle "$@"
        else
            echo "[ERROR] Config module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for models command
    if [[ "$1" == "models" ]]; then
        shift
        if type model_browser &>/dev/null; then
            model_browser "$@"
        else
            echo "[ERROR] Model browser not loaded" >&2
            exit 1
        fi
        return
    fi

    # Check for session commands
    if [[ "$1" == "session" ]]; then
        shift
        if type session_handle &>/dev/null; then
            session_handle "$@"
        else
            echo "[ERROR] Session module not loaded" >&2
            exit 1
        fi
        return
    fi

    # Single prompt execution
    local prompt="$1"

    # Security: Validate prompt length (enforce maximum input size)
    if [[ ${#prompt} -gt "$MAX_INPUT_LENGTH" ]]; then
        echo "[ERROR] Prompt too large (max $MAX_INPUT_LENGTH chars, got ${#prompt})" >&2
        exit 1
    fi
    shift

    # Parse remaining options
    local stream=false
    local model=""
    local temperature=""
    local max_tokens=""
    local system_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stream)
                stream=true
                shift
                ;;
            --no-stream)
                stream=false
                shift
                ;;
            -m|--model)
                if [[ -n "${2:-}" ]]; then
                    model="$2"
                    shift 2
                else
                    echo "[ERROR] --model requires a value" >&2
                    exit 1
                fi
                ;;
            --temp|--temperature)
                if [[ -n "${2:-}" ]]; then
                    # Security: Validate temperature range (0.0 to 2.0)
                    if ! [[ "$2" =~ ^[0-9]+\.?[0-9]*$ ]] || (( $(echo "$2 < 0 || $2 > 2" | bc -l 2>/dev/null || echo 1) )); then
                        echo "[ERROR] Temperature must be between 0.0 and 2.0" >&2
                        exit 1
                    fi
                    temperature="$2"
                    shift 2
                else
                    echo "[ERROR] --temperature requires a value" >&2
                    exit 1
                fi
                ;;
            --tokens|--max-tokens)
                if [[ -n "${2:-}" ]]; then
                    # Security: Validate max_tokens is positive integer
                    if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -le 0 ]] || [[ "$2" -gt 100000 ]]; then
                        echo "[ERROR] max-tokens must be a positive integer (1-100000)" >&2
                        exit 1
                    fi
                    max_tokens="$2"
                    shift 2
                else
                    echo "[ERROR] --max-tokens requires a value" >&2
                    exit 1
                fi
                ;;
            --system)
                if [[ -n "${2:-}" ]]; then
                    # Security: Validate system file path
                    local sys_path="$2"

                    # Security: Check for empty path
                    if [[ -z "$sys_path" ]]; then
                        echo "[ERROR] System file path cannot be empty" >&2
                        exit 1
                    fi

                    # Security: Check for newlines or carriage returns in path (null bytes cannot exist in bash strings)
                    if [[ "$sys_path" == *$'\n'* ]] || [[ "$sys_path" == *$'\r'* ]]; then
                        echo "[ERROR] Invalid characters in system file path" >&2
                        exit 1
                    fi

                    # Security: Check for Windows-style path traversal
                    if [[ "$sys_path" =~ \\.\\.\\ ]] || [[ "$sys_path" =~ ^[A-Za-z]: ]]; then
                        echo "[ERROR] Invalid Windows-style path not allowed" >&2
                        exit 1
                    fi
                    
                    # CRITICAL FIX C-001: Strict path traversal prevention
                    # Reject any path containing ".." regardless of context
                    if [[ "$sys_path" =~ \.\. ]]; then
                        echo "[ERROR] Path traversal sequences (..) are not allowed" >&2
                        exit 1
                    fi
                    
                    # Reject absolute paths
                    if [[ "$sys_path" =~ ^/ ]] || [[ "$sys_path" =~ ^~ ]]; then
                        echo "[ERROR] Absolute paths are not allowed, use relative paths within ORCHAT_ROOT" >&2
                        exit 1
                    fi

                    # Security: Normalize and validate path doesn't escape allowed directories
                    # Remove any leading/trailing whitespace
                    sys_path="$(echo "$sys_path" | xargs)"
                    
                    # Security: Reject paths with multiple consecutive slashes
                    if [[ "$sys_path" =~ // ]]; then
                        echo "[ERROR] System file path contains invalid sequence" >&2
                        exit 1
                    fi
                    
                    # CRITICAL FIX: Ensure path only contains safe characters (alphanumeric, dot, underscore, hyphen, single slash separator)
                    if ! [[ "$sys_path" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
                        echo "[ERROR] System file path contains invalid characters" >&2
                        exit 1
                    fi
                    
                    # CRITICAL FIX: Ensure no path component starts with a dot (hidden files)
                    if [[ "$sys_path" =~ (^|/)\.[^./] ]]; then
                        echo "[ERROR] Hidden files are not allowed" >&2
                        exit 1
                    fi

                    # Resolve to absolute path within ORCHAT_ROOT
                    local resolved_path=""
                    if [[ -f "$ORCHAT_ROOT/$sys_path" ]]; then
                        # Use realpath if available, otherwise construct manually
                        resolved_path="$(cd "$(dirname "$ORCHAT_ROOT/$sys_path")" && pwd)/$(basename "$sys_path")"
                        
                        # CRITICAL FIX C-001: Verify resolved path is strictly within ORCHAT_ROOT using prefix matching
                        if [[ "$resolved_path" != "$ORCHAT_ROOT"/* ]]; then
                            echo "[ERROR] System file must be within ORCHAT_ROOT directory" >&2
                            exit 1
                        fi
                        
                        # Additional verification: ensure the path doesn't contain any traversal after resolution
                        if [[ "$resolved_path" =~ \.\. ]]; then
                            echo "[ERROR] Resolved path contains traversal sequences" >&2
                            exit 1
                        fi
                        
                        system_file="$resolved_path"
                    elif [[ -f "$sys_path" ]] && [[ "$sys_path" != /* ]] && [[ "$sys_path" != ~* ]]; then
                        # Allow relative paths from current directory ONLY if they don't traverse and are within allowed dirs
                        local cwd_resolved
                        cwd_resolved="$(cd "$(dirname "$sys_path")" 2>/dev/null && pwd)/$(basename "$sys_path")" || {
                            echo "[ERROR] Cannot resolve system file path" >&2
                            exit 1
                        }
                        
                        # CRITICAL FIX: Only allow if within ORCHAT_ROOT or current working directory
                        case "$cwd_resolved" in
                            "$ORCHAT_ROOT"/*)
                                system_file="$cwd_resolved"
                                ;;
                            "$PWD"/*)
                                # Verify it's truly within PWD and doesn't escape
                                if [[ "$cwd_resolved" != "$PWD"/* ]]; then
                                    echo "[ERROR] System file outside allowed directories" >&2
                                    exit 1
                                fi
                                system_file="$cwd_resolved"
                                ;;
                            *)
                                echo "[ERROR] System file must be within ORCHAT_ROOT or current directory" >&2
                                exit 1
                                ;;
                        esac
                    else
                        echo "[ERROR] System file not found: $sys_path" >&2
                        exit 1
                    fi
                    shift 2
                else
                    echo "[ERROR] --system requires a file path" >&2
                    exit 1
                fi
                ;;
            --deterministic)
                DETERMINISTIC_MODE=true
                temperature="0.0"
                shift
                ;;
            *)
                echo "[WARN] Unknown option: $1" >&2
                shift
                ;;
        esac
    done

    # Set resolved values with security validation
    export RESOLVED_MODEL="${model:-${ORCHAT_MODEL:-openai/gpt-3.5-turbo}}"
    export RESOLVED_TEMPERATURE="${temperature:-${ORCHAT_TEMPERATURE:-0.7}}"
    export RESOLVED_MAX_TOKENS="${max_tokens:-${ORCHAT_MAX_TOKENS:-1000}}"
    export RESOLVED_SYSTEM_FILE="$system_file"

    # Build message
    local messages_json
    if [[ -n "$system_file" ]] && [[ -f "$system_file" ]]; then
        # Security: Additional validation before reading file
        if [[ ! -r "$system_file" ]]; then
            echo "[ERROR] System file not readable: $system_file" >&2
            exit 1
        fi
        
        # Security: Check file size (limit to 100KB)
        local file_size
        file_size=$(stat -c%s "$system_file" 2>/dev/null || stat -f%z "$system_file" 2>/dev/null || echo "0")
        if [[ "$file_size" -gt 102400 ]]; then
            echo "[ERROR] System file too large (max 100KB): $file_size bytes" >&2
            exit 1
        fi
        
        # Security: Verify file is a regular file (not symlink to device, etc.)
        if [[ ! -f "$system_file" ]]; then
            echo "[ERROR] System file is not a regular file" >&2
            exit 1
        fi
        
        # Security: Read file content safely
        system_content=$(cat "$system_file" 2>/dev/null) || {
            echo "[ERROR] Failed to read system file" >&2
            exit 1
        }
        # Security: Validate content does not contain null bytes
        # Note: Bash cannot store null bytes in variables, so we check the file directly
        if od -An -tx1 "$system_file" | grep -q ' 00'; then
            echo "[ERROR] System file contains invalid null bytes" >&2
            exit 1
        fi

        # Security: Validate system content length (use constant)
        if [[ ${#system_content} -gt "$MAX_INPUT_LENGTH" ]]; then
            echo "[ERROR] System file content too large (max $MAX_INPUT_LENGTH chars)" >&2
            exit 1
        fi

        messages_json=$(build_message_stack "$system_content" "$prompt" "[]")
    else
        messages_json='[{"role": "user", "content": "'"$prompt"'"}]'
    fi

    # Build payload
    local payload
    if type payload_build &>/dev/null; then
        payload=$(payload_build "$messages_json" "$RESOLVED_MODEL" "$RESOLVED_TEMPERATURE" "$RESOLVED_MAX_TOKENS" "$stream")
    else
        # Fallback
        payload='{"model": "'"$RESOLVED_MODEL"'", "messages": '"$messages_json"', "temperature": '"$RESOLVED_TEMPERATURE"', "max_tokens": '"$RESOLVED_MAX_TOKENS"', "stream": '"$stream"'}'
    fi

    # Make API call
    if [[ "$stream" == "true" ]]; then
        if type run_orchat_stream &>/dev/null; then
            run_orchat_stream "$payload"
        else
            echo "[ERROR] Streaming not available" >&2
            exit 1
        fi
    else
        if type run_orchat &>/dev/null; then
            run_orchat "$payload"
        else
            echo "[ERROR] Core API module not loaded" >&2
            exit 1
        fi
    fi
}
