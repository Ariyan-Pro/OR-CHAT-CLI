#!/usr/bin/env bash
# ignore.sh - Load and apply ignore rules
# 50+ years: Zero surprises, deterministic filtering

load_ignore_rules() {
    local root_dir="$1"
    local ignore_file
    local -a ignore_patterns=()
    
    # Built-in defaults (non-negotiable)
    local -a builtin_patterns=(
        ".git/"
        ".git/*"
        "node_modules/"
        "node_modules/*"
        "dist/"
        "dist/*"
        "build/"
        "build/*"
        "__pycache__/"
        "__pycache__/*"
        "*.pyc"
        "*.pyo"
        "*.pyd"
        ".Python"
        "*.so"
        "*.dylib"
        "bin/"
        "obj/"
        "*.suo"
        "*.tmp"
        "*.bak"
        "*.swp"
        "*.swo"
        "*~"
        "*.log"
        "logs/"
        ".DS_Store"
        "Thumbs.db"
        ".orchat/"
        ".orchat/*"
        ".vscode/"
        ".idea/"
        ".env"
        ".env.*"
        "*.secret"
        "*.key"
        ".venv/"
        "venv/"
        "env/"
        ".pytest_cache/"
        ".coverage"
        "htmlcov/"
        ".tox/"
        ".mypy_cache/"
        ".ruff_cache/"
    )
    
    ignore_patterns+=("${builtin_patterns[@]}")
    
    # Load .orchatignore if exists
    ignore_file="$root_dir/.orchatignore"
    if [[ -f "$ignore_file" ]]; then
        while IFS= read -r pattern || [[ -n "$pattern" ]]; do
            # Skip empty lines and comments
            [[ -z "$pattern" ]] && continue
            [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
            ignore_patterns+=("$pattern")
        done < "$ignore_file"
    fi
    
    # Load .gitignore if exists
    ignore_file="$root_dir/.gitignore"
    if [[ -f "$ignore_file" ]]; then
        while IFS= read -r pattern || [[ -n "$pattern" ]]; do
            # Skip empty lines and comments
            [[ -z "$pattern" ]] && continue
            [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
            ignore_patterns+=("$pattern")
        done < "$ignore_file"
    fi
    
    # Return patterns as newline-separated list
    printf '%s\n' "${ignore_patterns[@]}"
}

# Test if a file should be ignored
should_ignore() {
    local file_path="$1"
    shift
    local -a patterns=("$@")
    
    local pattern
    for pattern in "${patterns[@]}"; do
        # Simple glob matching (for now)
        if [[ "$file_path" == $pattern ]] || 
           [[ "$file_path" == */$pattern ]] ||
           [[ "$file_path" == $pattern/* ]] ||
           [[ "$file_path" == */$pattern/* ]]; then
            return 0  # Should ignore
        fi
    done
    
    return 1  # Should not ignore
}

# If called directly, test the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "load" ]]; then
        load_ignore_rules "$2"
    fi
fi
