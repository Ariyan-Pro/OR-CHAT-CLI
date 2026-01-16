#!/usr/bin/env bash
# assist.sh - AI-powered code assistance
# 50+ years: Augment, don't replace, human intelligence

# Configuration
ASSIST_MAX_CONTEXT=8000  # Tokens
ASSIST_TEMPERATURE=0.3   # Low temperature for code
ASSIST_MODEL="openrouter/quasar-alpha"

# Load workspace modules
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/analyze.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/analyze.sh"
fi

# Generate AI context from workspace
generate_ai_context() {
    local query="$1"
    local max_files="${2:-5}"
    
    echo "Building context for: '$query'"
    echo ""
    
    # Start with workspace status
    local context="## WORKSPACE CONTEXT\n"
    context+="Project: $(basename "$(pwd)")\n"
    context+="Location: $(pwd)\n"
    context+="\n"
    
    # Add file analysis based on query
    if [[ "$query" == *"code"* ]] || [[ "$query" == *"function"* ]] || [[ "$query" == *"class"* ]]; then
        context+="## CODE ANALYSIS\n"
        
        # Find and analyze relevant code files
        local -a code_files
        mapfile -t code_files < <(find . -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" \) \
            ! -path "./.*" ! -path "*/node_modules/*" 2>/dev/null | head -$max_files)
        
        for file in "${code_files[@]}"; do
            context+="\n### File: $(basename "$file")\n"
            context+="Path: $file\n"
            
            # Get basic file info
            if [[ -f "$file" ]]; then
                local language
                language=$(detect_language "$file")
                local lines
                lines=$(wc -l < "$file" 2>/dev/null || echo 0)
                
                context+="Language: $language\n"
                context+="Lines: $lines\n"
                
                # Add function signatures for code files
                if [[ "$language" == "bash" ]]; then
                    local functions
                    functions=$(grep '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()[[:space:]]*{' "$file" 2>/dev/null | head -5 | sed 's/^[[:space:]]*//')
                    [[ -n "$functions" ]] && context+="Functions:\n$functions\n"
                elif [[ "$language" == "python" ]]; then
                    local functions
                    functions=$(grep '^[[:space:]]*def[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null | head -5 | sed 's/^[[:space:]]*//')
                    [[ -n "$functions" ]] && context+="Functions:\n$functions\n"
                fi
                
                # Add first few lines for context
                context+="Preview:\n"
                context+="$(head -10 "$file" 2>/dev/null | sed 's/^/  /')\n"
            fi
        done
        
    elif [[ "$query" == *"config"* ]] || [[ "$query" == *"setting"* ]]; then
        context+="## CONFIGURATION FILES\n"
        
        # Find config files
        local -a config_files
        mapfile -t config_files < <(find . -type f \( -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" \) \
            ! -path "./.*" ! -path "*/node_modules/*" 2>/dev/null | head -$max_files)
        
        for file in "${config_files[@]}"; do
            context+="\n### File: $(basename "$file")\n"
            if [[ -f "$file" ]]; then
                context+="$(head -20 "$file" 2>/dev/null | sed 's/^/  /')\n"
            fi
        done
        
    elif [[ "$query" == *"doc"* ]] || [[ "$query" == *"readme"* ]]; then
        context+="## DOCUMENTATION\n"
        
        # Find documentation
        if [[ -f "README.md" ]]; then
            context+="\n### README.md\n"
            context+="$(head -30 "README.md" 2>/dev/null | sed 's/^/  /')\n"
        fi
        
        local -a doc_files
        mapfile -t doc_files < <(find . -type f -name "*.md" ! -path "./.*" ! -path "*/node_modules/*" 2>/dev/null | head -$max_files)
        
        for file in "${doc_files[@]}"; do
            [[ "$file" == "./README.md" ]] && continue
            context+="\n### File: $(basename "$file")\n"
            context+="$(head -20 "$file" 2>/dev/null | sed 's/^/  /')\n"
        done
        
    else
        # General context
        context+="## PROJECT OVERVIEW\n"
        
        # Count files by type
        local sh_files py_files js_files md_files json_files
        sh_files=$(find . -name "*.sh" ! -path "./.*" 2>/dev/null | wc -l)
        py_files=$(find . -name "*.py" ! -path "./.*" 2>/dev/null | wc -l)
        js_files=$(find . -name "*.js" ! -path "./.*" 2>/dev/null | wc -l)
        md_files=$(find . -name "*.md" ! -path "./.*" 2>/dev/null | wc -l)
        json_files=$(find . -name "*.json" ! -path "./.*" 2>/dev/null | wc -l)
        
        context+="File types:\n"
        [[ $sh_files -gt 0 ]] && context+="  - Shell scripts: $sh_files\n"
        [[ $py_files -gt 0 ]] && context+="  - Python files: $py_files\n"
        [[ $js_files -gt 0 ]] && context+="  - JavaScript files: $js_files\n"
        [[ $md_files -gt 0 ]] && context+="  - Markdown files: $md_files\n"
        [[ $json_files -gt 0 ]] && context+="  - JSON files: $json_files\n"
        context+="\n"
        
        # Key project files
        context+="Key files:\n"
        [[ -f "README.md" ]] && context+="  - README.md\n"
        [[ -f "package.json" ]] && context+="  - package.json\n"
        [[ -f "pyproject.toml" ]] && context+="  - pyproject.toml\n"
        [[ -d "src" ]] && context+="  - src/\n"
        [[ -d "tests" ]] && context+="  - tests/\n"
    fi
    
    # Add query-specific guidance
    context+="\n## USER QUERY\n"
    context+="$query\n"
    context+="\n## ASSISTANCE REQUEST\n"
    context+="Please provide helpful, specific assistance based on the above context.\n"
    context+="Be concise and focus on practical solutions.\n"
    
    echo -e "$context"
}

# Smart code suggestions
suggest_code() {
    local pattern="$1"
    local language="${2:-bash}"
    
    echo "Looking for '$pattern' in $language code..."
    echo ""
    
    case "$language" in
        bash)
            echo "Common bash patterns for '$pattern':"
            echo ""
            
            if [[ "$pattern" == *"function"* ]]; then
                echo "Function definition:"
                echo "  function_name() {"
                echo "    # Function body"
                echo "    local var=\"value\""
                echo "    echo \"\$var\""
                echo "  }"
                echo ""
                echo "Function with arguments:"
                echo "  process_file() {"
                echo "    local file=\"\$1\""
                echo "    local option=\"\$2\""
                echo "    # Process file"
                echo "  }"
                echo ""
            elif [[ "$pattern" == *"loop"* ]]; then
                echo "For loop over files:"
                echo "  for file in *.txt; do"
                echo "    echo \"Processing \$file\""
                echo "    # Process file"
                echo "  done"
                echo ""
                echo "While loop reading input:"
                echo "  while read -r line; do"
                echo "    echo \"Line: \$line\""
                echo "  done < input.txt"
                echo ""
            elif [[ "$pattern" == *"error"* ]] || [[ "$pattern" == *"check"* ]]; then
                echo "Error handling:"
                echo "  if [[ ! -f \"\$file\" ]]; then"
                echo "    echo \"Error: File not found: \$file\" >&2"
                echo "    return 1"
                echo "  fi"
                echo ""
                echo "Command error checking:"
                echo "  if ! command; then"
                echo "    echo \"Command failed\" >&2"
                echo "    exit 1"
                echo "  fi"
                echo ""
            fi
            ;;
            
        python)
            echo "Common Python patterns for '$pattern':"
            echo ""
            
            if [[ "$pattern" == *"function"* ]] || [[ "$pattern" == *"def"* ]]; then
                echo "Function with docstring:"
                echo "  def process_data(input_file, output_file):"
                echo "      \"\"\"Process data from input to output.\"\"\""
                echo "      with open(input_file) as f:"
                echo "          data = f.read()"
                echo "      # Process data"
                echo "      return result"
                echo ""
            elif [[ "$pattern" == *"class"* ]]; then
                echo "Class definition:"
                echo "  class DataProcessor:"
                echo "      def __init__(self, config):"
                echo "          self.config = config"
                echo ""
                echo "      def process(self):"
                echo "          # Processing logic"
                echo "          pass"
                echo ""
            fi
            ;;
            
        *)
            echo "General programming patterns:"
            echo ""
            echo "1. Always validate inputs"
            echo "2. Use meaningful variable names"
            echo "3. Add comments for complex logic"
            echo "4. Handle errors gracefully"
            echo "5. Write modular, reusable code"
            echo ""
            ;;
    esac
}

# Intelligent code review
review_code() {
    local file="$1"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; return 1; }
    
    echo "=== CODE REVIEW: $(basename "$file") ==="
    echo ""
    
    local language
    language=$(detect_language "$file")
    
    echo "Language: $language"
    echo ""
    
    # Basic checks
    local lines
    lines=$(wc -l < "$file" 2>/dev/null || echo 0)
    
    if [[ $lines -gt 500 ]]; then
        echo "⚠️  File is large ($lines lines). Consider splitting into smaller modules."
        echo ""
    fi
    
    # Language-specific checks
    case "$language" in
        bash)
            echo "Bash-specific checks:"
            echo ""
            
            # Check for shebang
            if ! head -1 "$file" | grep -q '^#!/'; then
                echo "❌ Missing shebang line. Add: #!/usr/bin/env bash"
            else
                echo "✅ Has shebang line"
            fi
            
            # Check for set -euo pipefail
            if ! grep -q 'set -euo pipefail' "$file"; then
                echo "⚠️  Consider adding 'set -euo pipefail' for stricter error handling"
            else
                echo "✅ Uses strict mode"
            fi
            
            # Check for long lines
            local long_lines
            long_lines=$(awk 'length > 100' "$file" 2>/dev/null | wc -l || echo 0)
            if [[ $long_lines -gt 0 ]]; then
                echo "⚠️  $long_lines lines exceed 100 characters"
            fi
            
            # Check for unquoted variables
            local unquoted
            unquoted=$(grep -n '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$file" 2>/dev/null | grep -v '#\|echo' | head -3 || true)
            if [[ -n "$unquoted" ]]; then
                echo "⚠️  Possible unquoted variables. Consider quoting: \"\$variable\""
                echo "$unquoted" | sed 's/^/  Line /'
            fi
            ;;
            
        python)
            echo "Python-specific checks:"
            echo ""
            
            # Check for imports
            local imports
            imports=$(grep -c '^import\|^from' "$file" || echo 0)
            echo "Imports: $imports"
            
            # Check for main guard
            if ! grep -q 'if __name__ == "__main__":' "$file"; then
                echo "⚠️  Consider adding main guard: if __name__ == \"__main__\":"
            else
                echo "✅ Has main guard"
            fi
            ;;
    esac
    
    echo ""
    echo "Overall assessment:"
    if [[ $lines -lt 50 ]]; then
        echo "✅ File is concise and focused"
    elif [[ $lines -lt 200 ]]; then
        echo "✅ File size is reasonable"
    else
        echo "⚠️  Consider if this file does too much"
    fi
}

# Explain code
explain_code() {
    local file="$1"
    local section="${2:-all}"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; return 1; }
    
    echo "=== EXPLAINING: $(basename "$file") ==="
    echo ""
    
    local language
    language=$(detect_language "$file")
    
    echo "File: $file"
    echo "Language: $language"
    echo "Section: $section"
    echo ""
    
    case "$language" in
        bash)
            echo "This is a Bash shell script."
            echo "Bash scripts automate command-line tasks."
            echo ""
            
            if [[ "$section" == "all" ]] || [[ "$section" == "header" ]]; then
                echo "## File Header"
                head -5 "$file" | sed 's/^/  /'
                echo ""
                echo "The header typically includes:"
                echo "1. Shebang (#!) - tells system which interpreter to use"
                echo "2. Comments describing the script's purpose"
                echo "3. Configuration settings"
                echo ""
            fi
            
            if [[ "$section" == "all" ]] || [[ "$section" == "functions" ]]; then
                echo "## Functions"
                grep '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()[[:space:]]*{' "$file" 2>/dev/null | sed 's/^/  /' || echo "  (No functions found)"
                echo ""
                echo "Functions help organize code into reusable blocks."
                echo ""
            fi
            
            echo "## Key Concepts"
            echo "1. Variables: store data (var=\"value\")"
            echo "2. Conditionals: if/then/else for decision making"
            echo "3. Loops: for/while for repetition"
            echo "4. Commands: execute system programs"
            echo "5. Error handling: set -e, trap, error checking"
            ;;
            
        python)
            echo "This is a Python script."
            echo "Python is a general-purpose programming language."
            echo ""
            echo "## Key Concepts"
            echo "1. Functions: def name(): reusable code blocks"
            echo "2. Classes: object-oriented programming"
            echo "3. Imports: use code from other modules"
            echo "4. Control flow: if/else, for/while loops"
            echo "5. Error handling: try/except blocks"
            ;;
            
        *)
            echo "This is a $language file."
            echo "Preview of content:"
            head -20 "$file" | sed 's/^/  /'
            ;;
    esac
    
    echo ""
    echo "To understand specific parts, ask about:"
    echo "- Functions or methods"
    echo "- Configuration options"
    echo "- Data flow"
    echo "- Error handling"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Test mode
    case "$1" in
        "context")
            generate_ai_context "${2:-"help with code"}" "${3:-3}"
            ;;
        "suggest")
            suggest_code "${2:-"function"}" "${3:-bash}"
            ;;
        "review")
            review_code "${2:-$0}"
            ;;
        "explain")
            explain_code "${2:-$0}" "${3:-all}"
            ;;
        "test")
            echo "Testing AI assistant..."
            generate_ai_context "test query" 2 | head -30
            ;;
        *)
            echo "Usage: $0 {context <query> [files]|suggest <pattern> [lang]|review <file>|explain <file> [section]|test}"
            ;;
    esac
fi

# Add flush to ensure complete output
generate_ai_context_flush() {
    local query="$1"
    local max_files="${2:-5}"
    
    # Generate and immediately flush
    generate_ai_context "$query" "$max_files"
    
    # Force flush all buffers
    sync 2>/dev/null || true
    echo ""
}
