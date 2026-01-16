#!/usr/bin/env bash
# ORCHAT Bootstrap - Phase 3 Complete
set -euo pipefail

# Determine root directory
ORCHAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ORCHAT_ROOT

# Load all modules in dependency order
for module in constants utils config env core io interactive streaming model_browser history context payload gemini_integration session workspace; do
    module_file="$ORCHAT_ROOT/src/$module.sh"

    if [[ -f "$module_file" ]]; then
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

# Main entry point
main() {
    # Special cases: --help and --version
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
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
        echo "  -h, --help             Show this help"
        echo "  --version              Show version"
        exit 0
    fi
    
    if [[ "$1" == "--version" ]] || [[ "$1" == "-v" ]]; then
        echo "ORCHAT v0.3.3 - Workstream 3 Integrated"
        echo "Engineering: 50+ years legacy systems expertise"
        exit 0
    fi
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
    fi

    # Single prompt execution
    local prompt="$1"
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
                model="$2"
                shift 2
                ;;
            --temp|--temperature)
                temperature="$2"
                shift 2
                ;;
            --tokens|--max-tokens)
                max_tokens="$2"
                shift 2
                ;;
            --system)
                system_file="$2"
                shift 2
                ;;
            *)
                echo "[WARN] Unknown option: $1" >&2
                shift
                ;;
        esac
    done

    # Set resolved values
    export RESOLVED_MODEL="${model:-${ORCHAT_MODEL:-openai/gpt-3.5-turbo}}"
    export RESOLVED_TEMPERATURE="${temperature:-${ORCHAT_TEMPERATURE:-0.7}}"
    export RESOLVED_MAX_TOKENS="${max_tokens:-${ORCHAT_MAX_TOKENS:-1000}}"
    export RESOLVED_SYSTEM_FILE="$system_file"

    # Build message
    local messages_json
    if [[ -n "$system_file" ]] && [[ -f "$system_file" ]]; then
        system_content=$(<"$system_file")
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
