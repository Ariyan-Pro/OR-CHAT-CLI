#!/usr/bin/env bash
# summarize.sh - Produce human-readable project snapshot
# 50+ years: Deterministic output, no LLM, no bullshit

summarize_workspace() {
    local root_dir="${1:-$(pwd)}"
    
    # Detect project root and type
    local detection
    detection=$(source "$(dirname "$0")/detect_root.sh" "$root_dir")
    local project_root=$(echo "$detection" | head -1)
    local project_type=$(echo "$detection" | tail -1)
    
    # Load ignore patterns
    local -a ignore_patterns=()
    while IFS= read -r pattern; do
        ignore_patterns+=("$pattern")
    done < <(source "$(dirname "$0")/ignore.sh" && load_ignore_rules "$project_root")
    
    # Scan files
    local scan_results
    scan_results=$(source "$(dirname "$0")/scan_files.sh" && scan_project_files "$project_root" "${ignore_patterns[@]}")
    
    # Parse scan results
    local file_count=0
    local total_size=0
    local -a file_types=()
    local -a key_files=()
    
    while IFS= read -r line; do
        case "$line" in
            FILE_COUNT:*)
                file_count="${line#FILE_COUNT:}"
                ;;
            TOTAL_SIZE:*)
                total_size="${line#TOTAL_SIZE:}"
                ;;
            FILE_TYPE:*)
                file_types+=("${line#FILE_TYPE:}")
                ;;
            KEY_FILE:*)
                key_files+=("${line#KEY_FILE:}")
                ;;
        esac
    done <<< "$scan_results"
    
    # Get git info if available
    local git_branch=""
    local git_commit=""
    if [[ -d "$project_root/.git" ]]; then
        git_branch=$(cd "$project_root" && git branch --show-current 2>/dev/null || echo "detached")
        git_commit=$(cd "$project_root" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    
    # Calculate ignored files count (approximate)
    local ignored_count=0
    if [[ -d "$project_root/.git" ]]; then
        ignored_count=$(cd "$project_root" && git status --ignored --porcelain 2>/dev/null | grep '^!!' | wc -l)
    fi
    
    # Format size for display
    local size_display
    if [[ $total_size -lt 1024 ]]; then
        size_display="${total_size}B"
    elif [[ $total_size -lt 1048576 ]]; then
        size_display="$((total_size / 1024))KB"
    else
        size_display="$((total_size / 1048576))MB"
    fi
    
    # Generate summary
    echo "Project root: $project_root"
    echo "Project type: $project_type"
    
    if [[ -n "$git_branch" ]]; then
        echo "Git repo: yes (branch: $git_branch, commit: $git_commit)"
    else
        echo "Git repo: no"
    fi
    
    echo "Tracked files: $file_count"
    echo "Total size: $size_display"
    
    if [[ $ignored_count -gt 0 ]]; then
        echo "Ignored files: $ignored_count"
    fi
    
    # Show top file types
    if [[ ${#file_types[@]} -gt 0 ]]; then
        echo "File types:"
        for type_info in "${file_types[@]}"; do
            local ext="${type_info%:*}"
            local count="${type_info#*:}"
            echo "  - .$ext: $count files"
        done
    fi
    
    # Show key files
    if [[ ${#key_files[@]} -gt 0 ]]; then
        echo "Key files:"
        for key_file in "${key_files[@]}"; do
            echo "  - $key_file"
        done
    fi
    
    # Add context about the workspace
    echo ""
    echo "Workspace Context:"
    echo "  - Current dir: $(pwd)"
    echo "  - Relative to root: $(realpath --relative-to="$project_root" "$(pwd)" 2>/dev/null || echo "N/A")"
    echo "  - Detection confidence: high (based on project markers)"
}

# If called directly, run summary
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    summarize_workspace "$@"
fi
