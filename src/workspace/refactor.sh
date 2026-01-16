#!/usr/bin/env bash
# refactor.sh - Architecture-preserving code refactoring
# 50+ years: Refactor like a surgeon, not a butcher

# Load workspace modules
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/analyze.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/analyze.sh"
fi

# Analyze code for refactoring opportunities
analyze_refactoring() {
    local file="$1"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; return 1; }
    
    local language
    language=$(detect_language "$file")
    
    echo "=== REFACTORING ANALYSIS ==="
    echo "File: $file"
    echo "Language: $language"
    echo ""
    
    local lines
    lines=$(wc -l < "$file" 2>/dev/null || echo 0)
    
    # Identify refactoring opportunities
    echo "## REFACTORING OPPORTUNITIES"
    echo ""
    
    case "$language" in
        bash)
            # Check for long functions
            echo "### FUNCTION ANALYSIS"
            local functions
            functions=$(grep -n '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()[[:space:]]*{' "$file" 2>/dev/null || true)
            
            if [[ -n "$functions" ]]; then
                echo "Found functions:"
                echo "$functions" | while read -r line; do
                    echo "  - Line $(echo "$line" | cut -d: -f1): $(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//')"
                done
                echo ""
                
                # Check function length (simplified)
                echo "### SUGGESTIONS"
                echo "1. Keep functions under 50 lines"
                echo "2. Each function should do one thing"
                echo "3. Extract complex logic into helper functions"
            else
                echo "No functions found (script may be procedural)"
                echo ""
                echo "### SUGGESTIONS"
                echo "1. Consider organizing into functions"
                echo "2. Extract reusable code blocks"
                echo "3. Add error handling"
            fi
            
            # Check for duplicated code
            echo ""
            echo "### CODE DUPLICATION CHECK"
            echo "Look for repeated patterns that could be functions"
            ;;
            
        python)
            echo "### PYTHON-SPECIFIC REFACTORING"
            echo ""
            echo "1. Check for long functions/methods"
            echo "2. Look for duplicated logic"
            echo "3. Consider using decorators for cross-cutting concerns"
            echo "4. Check if classes follow Single Responsibility Principle"
            echo "5. Look for opportunities to use context managers"
            ;;
    esac
    
    echo ""
    echo "## REFACTORING STRATEGY"
    echo "1. Understand current behavior"
    echo "2. Write tests first"
    echo "3. Make small, incremental changes"
    echo "4. Verify after each change"
    echo "5. Document the changes"
}

# Suggest refactoring patterns
suggest_refactoring() {
    local pattern="$1"
    local language="${2:-bash}"
    
    echo "=== REFACTORING PATTERN ==="
    echo "Pattern: $pattern"
    echo "Language: $language"
    echo ""
    
    case "$pattern" in
        "extract function"|"extract method")
            case "$language" in
                bash)
                    echo "## EXTRACT FUNCTION PATTERN (Bash)"
                    echo ""
                    echo "BEFORE:"
                    echo "  # Long procedural code"
                    echo "  input=\"\$1\""
                    echo "  if [[ -z \"\$input\" ]]; then"
                    echo "      echo \"Error: no input\" >&2"
                    echo "      exit 1"
                    echo "  fi"
                    echo "  # ... 20 more lines of processing ..."
                    echo ""
                    echo "AFTER:"
                    echo "  # Extracted validation function"
                    echo "  validate_input() {"
                    echo "      local input=\"\$1\""
                    echo "      if [[ -z \"\$input\" ]]; then"
                    echo "          echo \"Error: no input\" >&2"
                    echo "          return 1"
                    echo "      fi"
                    echo "  }"
                    echo ""
                    echo "  # Main logic"
                    echo "  input=\"\$1\""
                    echo "  validate_input \"\$input\" || exit 1"
                    echo "  # ... cleaner main logic ..."
                    ;;
                    
                python)
                    echo "## EXTRACT METHOD PATTERN (Python)"
                    echo ""
                    echo "BEFORE:"
                    echo "  def process_data(data):"
                    echo "      # Validation"
                    echo "      if not data:"
                    echo "          raise ValueError(\"No data\")"
                    echo "      # ... long processing logic ..."
                    echo ""
                    echo "AFTER:"
                    echo "  def validate_data(data):"
                    echo "      if not data:"
                    echo "          raise ValueError(\"No data\")"
                    echo ""
                    echo "  def process_data(data):"
                    echo "      validate_data(data)"
                    echo "      # ... focused processing logic ..."
                    ;;
            esac
            ;;
            
        "rename variable"|"better naming")
            echo "## IMPROVE VARIABLE NAMES"
            echo ""
            echo "PRINCIPLES:"
            echo "1. Names should reveal intent"
            echo "2. Avoid abbreviations"
            echo "3. Use consistent naming conventions"
            echo "4. Distinguish types with suffixes (list, dict, str)"
            echo ""
            echo "EXAMPLES:"
            echo "  Bad: x, tmp, var1, data2"
            echo "  Good: user_count, config_file, error_messages"
            ;;
            
        "simplify conditionals")
            echo "## SIMPLIFY CONDITIONALS"
            echo ""
            echo "TECHNIQUES:"
            echo "1. Extract complex conditions into named functions"
            echo "2. Use early returns to reduce nesting"
            echo "3. Replace nested ifs with guard clauses"
            echo "4. Consider using polymorphism for complex logic"
            ;;
            
        *)
            echo "## GENERAL REFACTORING PRINCIPLES"
            echo ""
            echo "1. Make it work, then make it right, then make it fast"
            echo "2. Refactor in small steps"
            echo "3. Keep tests passing"
            echo "4. Improve readability"
            echo "5. Remove duplication"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        "analyze")
            analyze_refactoring "${2:-$0}"
            ;;
        "suggest")
            suggest_refactoring "${2:-"extract function"}" "${3:-bash}"
            ;;
        "test")
            echo "Testing refactoring module..."
            analyze_refactoring "$0" | head -30
            ;;
        *)
            echo "Usage: $0 {analyze <file>|suggest <pattern> [lang]|test}"
            ;;
    esac
fi
