#!/usr/bin/env bash
# detect_root.sh - Find project root and type
# 50+ years: No guessing, no bullshit

detect_project_root() {
    local start_dir="${1:-$(pwd)}"
    local dir="$start_dir"
    local previous=""
    
    # Walk up the directory tree
    while [[ "$dir" != "$previous" ]]; do
        # Check for known project markers (in order of precedence)
        if [[ -d "$dir/.git" ]]; then
            echo "$dir"
            echo "git"
            return 0
        elif [[ -f "$dir/pyproject.toml" ]]; then
            echo "$dir"
            echo "python"
            return 0
        elif [[ -f "$dir/package.json" ]]; then
            echo "$dir"
            echo "node"
            return 0
        elif [[ -f "$dir/go.mod" ]]; then
            echo "$dir"
            echo "go"
            return 0
        elif [[ -f "$dir/Cargo.toml" ]]; then
            echo "$dir"
            echo "rust"
            return 0
        elif [[ -f "$dir/Makefile" ]] || [[ -f "$dir/makefile" ]]; then
            echo "$dir"
            echo "make"
            return 0
        elif [[ -f "$dir/README.md" ]] || [[ -f "$dir/README" ]]; then
            echo "$dir"
            echo "generic"
            return 0
        fi
        
        previous="$dir"
        dir="$(dirname "$dir")"
    done
    
    # Fallback: current directory
    echo "$start_dir"
    echo "unknown"
    return 0
}

# If called directly, run detection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_project_root "$@"
fi
