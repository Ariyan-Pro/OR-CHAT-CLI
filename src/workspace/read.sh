#!/usr/bin/env bash
# read.sh - Safe file reading with limits
# 50+ years: Never read more than you need

# Configuration
MAX_FILE_SIZE=1048576  # 1MB max
MAX_TOTAL_READ=5242880  # 5MB total limit
MAX_LINES_PER_FILE=1000

read_file_safely() {
    local file_path="$1"
    local max_lines="${2:-$MAX_LINES_PER_FILE}"
    local max_size="${3:-$MAX_FILE_SIZE}"
    
    # Safety checks
    [[ ! -f "$file_path" ]] && { echo "[ERROR] File not found: $file_path" >&2; return 1; }
    [[ ! -r "$file_path" ]] && { echo "[ERROR] Cannot read file: $file_path" >&2; return 1; }
    
    # Size check
    local file_size
    file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
    [[ -z "$file_size" ]] && file_size=0
    
    if [[ $file_size -gt $max_size ]]; then
        echo "[WARNING] File too large ($file_size > $max_size bytes), reading first $max_lines lines" >&2
        head -n "$max_lines" "$file_path"
        echo "... [truncated, file too large]" >&2
        return 0
    fi
    
    # Read the file
    if [[ $file_size -lt 10000 ]]; then
        # Small file, read all
        cat "$file_path"
    else
        # Larger file, limit lines
        head -n "$max_lines" "$file_path"
        if [[ $(wc -l < "$file_path" 2>/dev/null || echo 0) -gt $max_lines ]]; then
            echo "... [truncated to $max_lines lines]" >&2
        fi
    fi
    
    return 0
}

read_multiple_files() {
    local -a files=("$@")
    local total_read=0
    local file_count=0
    
    for file in "${files[@]}"; do
        [[ $total_read -ge $MAX_TOTAL_READ ]] && {
            echo "[WARNING] Total read limit reached ($MAX_TOTAL_READ bytes)" >&2
            break
        }
        
        if [[ -f "$file" ]] && [[ -r "$file" ]]; then
            echo "=== FILE: $file ==="
            read_file_safely "$file"
            echo ""
            file_count=$((file_count + 1))
            
            # Track size (approximate)
            local size
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
            total_read=$((total_read + size))
        else
            echo "[SKIP] Cannot read: $file" >&2
        fi
    done
    
    echo "[INFO] Read $file_count files, ~$total_read bytes" >&2
    return 0
}

# Smart file selection based on context
select_relevant_files() {
    local context="$1"
    local max_files="${2:-5}"
    local -a selected_files=()
    
    # Based on context, select appropriate files
    case "$context" in
        "config"|"configuration")
            find . -type f \( -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.conf" -o -name "*.cfg" \) \
                ! -path "./.*" ! -path "*/node_modules/*" ! -path "*/dist/*" 2>/dev/null | head -$max_files
            ;;
        "code"|"source")
            find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.cpp" \) \
                ! -path "./.*" ! -path "*/node_modules/*" ! -path "*/dist/*" 2>/dev/null | head -$max_files
            ;;
        "script"|"bash")
            find . -type f -name "*.sh" ! -path "./.*" ! -path "*/node_modules/*" 2>/dev/null | head -$max_files
            ;;
        "documentation"|"docs")
            find . -type f \( -name "*.md" -o -name "README*" -o -name "DOCS*" \) \
                ! -path "./.*" ! -path "*/node_modules/*" 2>/dev/null | head -$max_files
            ;;
        *)
            # Default: look for key project files
            local -a default_files=()
            [[ -f "./README.md" ]] && default_files+=("./README.md")
            [[ -f "./package.json" ]] && default_files+=("./package.json")
            [[ -f "./pyproject.toml" ]] && default_files+=("./pyproject.toml")
            [[ -f "./go.mod" ]] && default_files+=("./go.mod")
            [[ -f "./Cargo.toml" ]] && default_files+=("./Cargo.toml")
            [[ -f "./Makefile" ]] && default_files+=("./Makefile")
            
            if [[ ${#default_files[@]} -eq 0 ]]; then
                # Fallback: first few text files
                find . -type f -name "*.txt" -o -name "*.md" -o -name "*.rst" \
                    ! -path "./.*" ! -path "*/node_modules/*" 2>/dev/null | head -$max_files
            else
                printf '%s\n' "${default_files[@]}"
            fi
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Test mode
    if [[ "$1" == "test" ]]; then
        echo "Testing file reader..."
        read_file_safely "${2:-$0}" 10
    else
        echo "File reader module loaded."
    fi
fi
