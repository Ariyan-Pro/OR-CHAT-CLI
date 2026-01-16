#!/usr/bin/env bash
# context.sh - Manage file reading context
# 50+ years: Context is everything

# Load the file reader
source "$(dirname "${BASH_SOURCE[0]}")/read.sh"

# Context tracking
declare -A CONTEXT_HISTORY
MAX_CONTEXT_HISTORY=10

add_to_context() {
    local file_path="$1"
    local summary="${2:-}"
    
    if [[ -f "$file_path" ]]; then
        local key
        key=$(realpath "$file_path" 2>/dev/null || echo "$file_path")
        CONTEXT_HISTORY["$key"]="${summary:-$(basename "$file_path")}"
        
        # Limit history size
        if [[ ${#CONTEXT_HISTORY[@]} -gt $MAX_CONTEXT_HISTORY ]]; then
            # Remove oldest (bash doesn't preserve order, so remove first key)
            local first_key
            first_key=$(echo "${!CONTEXT_HISTORY[@]}" | awk '{print $1}')
            unset CONTEXT_HISTORY["$first_key"]
        fi
    fi
}

get_context_summary() {
    echo "=== CURRENT WORKSPACE CONTEXT ==="
    echo "Project: $(basename "$(pwd)")"
    echo "Location: $(pwd)"
    echo ""
    
    if [[ ${#CONTEXT_HISTORY[@]} -gt 0 ]]; then
        echo "Recently read files:"
        for file in "${!CONTEXT_HISTORY[@]}"; do
            echo "  - ${CONTEXT_HISTORY[$file]} ($file)"
        done | head -5
    else
        echo "No files read yet."
    fi
    
    # Show available files by type
    echo ""
    echo "Available file types:"
    local sh_count py_count js_count md_count json_count
    sh_count=$(find . -name "*.sh" ! -path "./.*" 2>/dev/null | wc -l)
    py_count=$(find . -name "*.py" ! -path "./.*" 2>/dev/null | wc -l)
    js_count=$(find . -name "*.js" ! -path "./.*" 2>/dev/null | wc -l)
    md_count=$(find . -name "*.md" ! -path "./.*" 2>/dev/null | wc -l)
    json_count=$(find . -name "*.json" ! -path "./.*" 2>/dev/null | wc -l)
    
    [[ $sh_count -gt 0 ]] && echo "  - Shell scripts: $sh_count"
    [[ $py_count -gt 0 ]] && echo "  - Python files: $py_count"
    [[ $js_count -gt 0 ]] && echo "  - JavaScript files: $js_count"
    [[ $md_count -gt 0 ]] && echo "  - Markdown files: $md_count"
    [[ $json_count -gt 0 ]] && echo "  - JSON files: $json_count"
}

read_with_context() {
    local query="$1"
    local max_files="${2:-3}"
    
    echo "Analyzing query: '$query'"
    echo ""
    
    # Determine context from query
    local context="general"
    case "$query" in
        *config*|*setting*|*option*) context="config" ;;
        *code*|*function*|*class*|*module*) context="code" ;;
        *script*|*bash*|*shell*) context="script" ;;
        *doc*|*readme*|*help*) context="documentation" ;;
        *test*|*spec*) context="test" ;;
    esac
    
    echo "Context detected: $context"
    echo "Searching for relevant files..."
    echo ""
    
    # Get relevant files
    local -a files
    mapfile -t files < <(select_relevant_files "$context" "$max_files")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No relevant files found for context: $context"
        return 1
    fi
    
    echo "Selected files:"
    printf '  - %s\n' "${files[@]}"
    echo ""
    
    # Read files
    read_multiple_files "${files[@]}"
    
    # Add to context history
    for file in "${files[@]}"; do
        add_to_context "$file" "Read for: $query"
    done
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Test mode
    case "$1" in
        "summary")
            get_context_summary
            ;;
        "read")
            read_with_context "${2:-}" "${3:-3}"
            ;;
        "test")
            echo "Testing context manager..."
            get_context_summary
            ;;
        *)
            echo "Usage: $0 {summary|read <query>|test}"
            ;;
    esac
fi
