#!/usr/bin/env bash
# UTF-8 BOM Detection and CRLF Normalization
# Handles encoding issues in input files and user input

set -eo pipefail

# UTF-8 BOM bytes (EF BB BF)
UTF8_BOM=$'\xef\xbb\xbf'

# Detect if file has UTF-8 BOM
detect_bom() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "none"
        return 1
    fi
    
    # Read first 3 bytes
    local first_bytes
    first_bytes=$(head -c 3 "$file" | od -An -tx1 | tr -d ' \n')
    
    if [[ "$first_bytes" == "efbbbf" ]]; then
        echo "utf-8-bom"
        return 0
    else
        echo "none"
        return 0
    fi
}

# Remove UTF-8 BOM from file
remove_bom() {
    local file="$1"
    local temp_file="${file}.tmp.$$"
    
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] File not found: $file" >&2
        return 1
    fi
    
    local bom_type
    bom_type=$(detect_bom "$file")
    
    if [[ "$bom_type" == "utf-8-bom" ]]; then
        # Skip first 3 bytes (BOM)
        tail -c +4 "$file" > "$temp_file"
        mv "$temp_file" "$file"
        echo "[INFO] Removed UTF-8 BOM from $file" >&2
        return 0
    else
        rm -f "$temp_file"
        return 0
    fi
}

# Remove BOM from string/content
remove_bom_from_string() {
    local content="$1"
    
    # Use printf and od to check for BOM bytes (EF BB BF)
    local first_bytes
    first_bytes=$(printf '%s' "$content" | head -c 3 | od -An -tx1 | tr -d ' \n')
    
    if [[ "$first_bytes" == "efbbbf" ]]; then
        # Remove first 3 bytes (BOM) using tail
        printf '%s' "$content" | tail -c +4
    else
        printf '%s' "$content"
    fi
}

# Detect line ending type
detect_line_endings() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "unknown"
        return 1
    fi
    
    # Check for CRLF (Windows)
    if grep -q $'\r\n' "$file" 2>/dev/null; then
        # Check if also has LF only (mixed)
        if grep -q $'\n' "$file" 2>/dev/null && ! grep -q $'\r$' "$file" 2>/dev/null; then
            echo "mixed"
        else
            echo "crlf"
        fi
    # Check for CR only (old Mac)
    elif grep -q $'\r' "$file" 2>/dev/null; then
        echo "cr"
    # LF only (Unix)
    else
        echo "lf"
    fi
    
    return 0
}

# Normalize line endings to LF (Unix style)
normalize_line_endings() {
    local file="$1"
    local temp_file="${file}.tmp.$$"
    
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] File not found: $file" >&2
        return 1
    fi
    
    local line_type
    line_type=$(detect_line_endings "$file")
    
    case "$line_type" in
        crlf|cr|mixed)
            # Convert CRLF and CR to LF
            sed 's/\r$//' "$file" | tr '\r' '\n' > "$temp_file"
            mv "$temp_file" "$file"
            echo "[INFO] Normalized line endings in $file (was: $line_type)" >&2
            return 0
            ;;
        lf)
            # Already normalized
            return 0
            ;;
        *)
            echo "[WARN] Could not detect line endings for $file" >&2
            return 1
            ;;
    esac
}

# Normalize line endings in string
normalize_line_endings_string() {
    local content="$1"
    
    # Convert CRLF to LF, then standalone CR to LF
    echo "$content" | sed 's/\r$//' | tr '\r' '\n'
}

# Complete encoding normalization (BOM removal + CRLF normalization)
normalize_encoding() {
    local file="$1"
    local changes_made=0
    
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] File not found: $file" >&2
        return 1
    fi
    
    # Remove BOM if present
    local bom_type
    bom_type=$(detect_bom "$file")
    if [[ "$bom_type" == "utf-8-bom" ]]; then
        remove_bom "$file"
        changes_made=1
    fi
    
    # Normalize line endings
    local line_type
    line_type=$(detect_line_endings "$file")
    if [[ "$line_type" != "lf" && "$line_type" != "unknown" ]]; then
        normalize_line_endings "$file"
        changes_made=1
    fi
    
    if [[ $changes_made -eq 1 ]]; then
        echo "[INFO] Encoding normalized for $file" >&2
    fi
    
    return 0
}

# Validate UTF-8 encoding
validate_utf8() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] File not found: $file" >&2
        return 1
    fi
    
    if iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1; then
        echo "valid"
        return 0
    else
        echo "invalid"
        return 1
    fi
}

# Force convert to UTF-8
convert_to_utf8() {
    local file="$1"
    local from_encoding="${2:-ISO-8859-1}"
    local temp_file="${file}.tmp.$$"
    
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] File not found: $file" >&2
        return 1
    fi
    
    if iconv -f "$from_encoding" -t UTF-8 "$file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$file"
        echo "[INFO] Converted $file from $from_encoding to UTF-8" >&2
        return 0
    else
        rm -f "$temp_file"
        echo "[ERROR] Failed to convert $file to UTF-8" >&2
        return 1
    fi
}

# Process input stream for BOM and CRLF
process_input_stream() {
    local input
    input=$(cat)
    
    # Remove BOM if present
    input=$(remove_bom_from_string "$input")
    
    # Normalize line endings
    input=$(normalize_line_endings_string "$input")
    
    echo "$input"
}

# Safe file read with encoding normalization
safe_read_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] File not found: $file" >&2
        return 1
    fi
    
    cat "$file" | process_input_stream
}
