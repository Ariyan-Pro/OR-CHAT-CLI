#!/usr/bin/env bash
# scan_files.sh - Enumerate and analyze files
# 50+ years: No file contents read, only metadata

scan_project_files() {
    local root_dir="$1"
    shift
    local -a ignore_patterns=("$@")
    
    local -A file_types=()
    local total_size=0
    local file_count=0
    local -a key_files=()
    
    # Use find to get all files, respecting .gitignore if git is present
    if [[ -d "$root_dir/.git" ]]; then
        # Use git ls-files for git repos (respects .gitignore automatically)
        while IFS= read -r file_path; do
            [[ -z "$file_path" ]] && continue
            
            # Check against additional ignore patterns
            if should_ignore "$file_path" "${ignore_patterns[@]}"; then
                continue
            fi
            
            file_count=$((file_count + 1))
            
            # Get file size
            if [[ -f "$root_dir/$file_path" ]]; then
                local size
                size=$(stat -c%s "$root_dir/$file_path" 2>/dev/null || stat -f%z "$root_dir/$file_path" 2>/dev/null || echo 0)
                total_size=$((total_size + size))
                
                # Track file type by extension
                local ext="${file_path##*.}"
                if [[ "$ext" != "$file_path" ]]; then
                    file_types["$ext"]=$((file_types["$ext"] + 1))
                else
                    file_types["no_extension"]=$((file_types["no_extension"] + 1))
                fi
                
                # Identify key files
                if [[ "$file_path" == "README.md" ]] || 
                   [[ "$file_path" == "README" ]] ||
                   [[ "$file_path" == "pyproject.toml" ]] ||
                   [[ "$file_path" == "package.json" ]] ||
                   [[ "$file_path" == "go.mod" ]] ||
                   [[ "$file_path" == "Cargo.toml" ]] ||
                   [[ "$file_path" == "Makefile" ]] ||
                   [[ "$file_path" == "makefile" ]] ||
                   [[ "$file_path" == "Dockerfile" ]] ||
                   [[ "$file_path" == "docker-compose.yml" ]] ||
                   [[ "$file_path" == ".env.example" ]] ||
                   [[ "$file_path" == "requirements.txt" ]] ||
                   [[ "$file_path" == "src/"* && ${#key_files[@]} -lt 10 ]] ||
                   [[ "$file_path" == "lib/"* && ${#key_files[@]} -lt 10 ]] ||
                   [[ "$file_path" == "app/"* && ${#key_files[@]} -lt 10 ]] ||
                   [[ "$file_path" == "test/"* && ${#key_files[@]} -lt 5 ]] ||
                   [[ "$file_path" == "tests/"* && ${#key_files[@]} -lt 5 ]]; then
                    key_files+=("$file_path")
                fi
            fi
        done < <(cd "$root_dir" && git ls-files 2>/dev/null)
    else
        # Non-git repo: use find with basic filtering
        while IFS= read -r file_path; do
            [[ -z "$file_path" ]] && continue
            
            # Make path relative to root
            local rel_path="${file_path#$root_dir/}"
            
            # Check against ignore patterns
            if should_ignore "$rel_path" "${ignore_patterns[@]}"; then
                continue
            fi
            
            file_count=$((file_count + 1))
            
            # Get file size
            local size
            size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo 0)
            total_size=$((total_size + size))
            
            # Track file type by extension
            local ext="${rel_path##*.}"
            if [[ "$ext" != "$rel_path" ]]; then
                file_types["$ext"]=$((file_types["$ext"] + 1))
            else
                file_types["no_extension"]=$((file_types["no_extension"] + 1))
            fi
            
            # Identify key files
            if [[ "$rel_path" == "README.md" ]] || 
               [[ "$rel_path" == "README" ]] ||
               [[ "$rel_path" == "pyproject.toml" ]] ||
               [[ "$rel_path" == "package.json" ]] ||
               [[ "$rel_path" == "go.mod" ]] ||
               [[ "$rel_path" == "Cargo.toml" ]] ||
               [[ "$rel_path" == "Makefile" ]] ||
               [[ "$rel_path" == "makefile" ]] ||
               [[ "$rel_path" == "Dockerfile" ]] ||
               [[ "$rel_path" == "docker-compose.yml" ]] ||
               [[ "$rel_path" == ".env.example" ]] ||
               [[ "$rel_path" == "requirements.txt" ]] ||
               [[ "$rel_path" == "src/"* && ${#key_files[@]} -lt 10 ]] ||
               [[ "$rel_path" == "lib/"* && ${#key_files[@]} -lt 10 ]] ||
               [[ "$rel_path" == "app/"* && ${#key_files[@]} -lt 10 ]] ||
               [[ "$rel_path" == "test/"* && ${#key_files[@]} -lt 5 ]] ||
               [[ "$rel_path" == "tests/"* && ${#key_files[@]} -lt 5 ]]; then
                key_files+=("$rel_path")
            fi
        done < <(find "$root_dir" -type f ! -path "$root_dir/.*" 2>/dev/null)
    fi
    
    # Output results
    echo "FILE_COUNT:$file_count"
    echo "TOTAL_SIZE:$total_size"
    
    # File types (top 10)
    local count=0
    for ext in "${!file_types[@]}"; do
        echo "FILE_TYPE:$ext:${file_types[$ext]}"
        count=$((count + 1))
        [[ $count -ge 10 ]] && break
    done
    
    # Key files
    for key_file in "${key_files[@]}"; do
        echo "KEY_FILE:$key_file"
    done
}

# If called directly, run scan
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Load ignore patterns
    source "$(dirname "$0")/ignore.sh"
    patterns=()
    while IFS= read -r pattern; do
        patterns+=("$pattern")
    done < <(load_ignore_rules "$(pwd)")
    
    scan_project_files "$(pwd)" "${patterns[@]}"
fi
