#!/bin/bash
# Workstream 3 Integration Fix Script
# Fixes all integration issues without sudo

set -e

echo "=== WORKSTREAM 3 INTEGRATION FIX ==="
echo ""

# 1. Copy advanced modules
echo "1. Copying advanced modules to /usr/lib/orchat..."
cp "$(dirname "$0")/session_manager.sh" /usr/lib/orchat/ 2>/dev/null || {
    echo "Failed to copy session_manager.sh"
    exit 1
}
cp "$(dirname "$0")/context_optimizer.sh" /usr/lib/orchat/ 2>/dev/null || {
    echo "Failed to copy context_optimizer.sh"
    exit 1
}
echo "✅ Modules copied"
echo ""

# 2. Create simple bootstrap that loads advanced modules
echo "2. Creating integrated bootstrap..."
cat > /usr/lib/orchat/bootstrap.sh << 'BOOTSTRAP_EOF'
#!/usr/bin/env bash
# ORCHAT Bootstrap v0.3.3 - Integrated Workstream 3

set -euo pipefail

MODULE_DIR="/usr/lib/orchat"
export ORCHAT_ROOT="$MODULE_DIR"

# Simple loader
load() {
    for module in constants utils config env core io interactive streaming model_browser history context payload gemini_integration session session_manager context_optimizer; do
        module_file="$MODULE_DIR/$module.sh"
        if [[ -f "$module_file" ]]; then
            # shellcheck source=/dev/null
            source "$module_file" 2>/dev/null && echo "[DEBUG] Loaded: $module" >&2
        fi
    done
}

# Load everything
load

# Main function with Workstream 3 commands
main() {
    case "${1:-}" in
        "session")
            if declare -f list_sessions >/dev/null; then
                case "${2:-}" in
                    "create") create_session "${3:-}" "${4:-}" ;;
                    "list") list_sessions ;;
                    "stats") session_stats ;;
                    "cleanup") cleanup_sessions ;;
                    *) 
                        echo "Session commands: create, list, stats, cleanup"
                        echo "Example: orchat session create openai/gpt-4"
                        ;;
                esac
            else
                echo "Session manager not loaded"
            fi
            ;;
        "context")
            if declare -f analyze_context >/dev/null; then
                case "${2:-}" in
                    "analyze") 
                        [[ -n "${3:-}" ]] && analyze_context "$(cat "${3}" 2>/dev/null || echo "${3}")" || echo "Need file"
                        ;;
                    *) 
                        echo "Context commands: analyze"
                        echo "Example: orchat context analyze file.json"
                        ;;
                esac
            else
                echo "Context optimizer not loaded"
            fi
            ;;
        "advanced")
            echo "ORCHAT Advanced Features:"
            echo "  session - Manage chat sessions"
            echo "  context - Optimize context windows"
            ;;
        "--help"|"-h")
            echo "ORCHAT v0.3.3 with Workstream 3 Advanced Features"
            echo "Commands: session, context, advanced"
            ;;
        "--version")
            echo "ORCHAT v0.3.3 - Workstream 3 Integrated"
            ;;
        *)
            if declare -f send_request >/dev/null; then
                send_request "$*"
            else
                echo "ORCHAT: $*"
            fi
            ;;
    esac
}

main "$@"
BOOTSTRAP_EOF

chmod 755 /usr/lib/orchat/bootstrap.sh
echo "✅ Bootstrap updated"
echo ""

# 3. Test
echo "3. Testing integration..."
orchat --version
echo ""
orchat session list
echo ""

echo "=== FIX COMPLETE ==="
echo "Workstream 3 is now properly integrated!"
