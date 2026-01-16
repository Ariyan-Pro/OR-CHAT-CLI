#!/usr/bin/env bash
# generate.sh - Intelligent code generation
# 50+ years: Generate code that looks like you wrote it

# Load workspace modules
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/analyze.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/analyze.sh"
fi

# Generate context for code generation
generate_code_context() {
    local description="$1"
    local language="${2:-bash}"
    local max_context="${3:-5000}"
    
    echo "## CODE GENERATION REQUEST"
    echo "Language: $language"
    echo "Description: $description"
    echo ""
    
    # Get project context
    local context="## PROJECT CONTEXT\n"
    context+="Project: $(basename "$(pwd)")\n"
    context+="\n"
    
    # Language-specific patterns
    context+="## LANGUAGE PATTERNS - $language\n"
    
    case "$language" in
        bash)
            context+="### BASH STYLE GUIDE\n"
            context+="1. Use 'set -euo pipefail' for error handling\n"
            context+="2. Quote all variables: \"\$variable\"\n"
            context+="3. Use [[ ]] for conditionals\n"
            context+="4. Use local for function variables\n"
            context+="5. Include help/usage functions\n"
            context+="6. Validate inputs\n"
            context+="7. Use meaningful exit codes\n"
            context+="\n"
            
            # Add examples from project
            local bash_files
            bash_files=$(find . -name "*.sh" ! -path "./.*" 2>/dev/null | head -3)
            if [[ -n "$bash_files" ]]; then
                context+="### PROJECT BASH EXAMPLES\n"
                for file in $bash_files; do
                    context+="\nFile: $(basename "$file")\n"
                    context+="$(head -20 "$file" 2>/dev/null | sed 's/^/  /')\n"
                done
            fi
            ;;
            
        python)
            context+="### PYTHON STYLE GUIDE\n"
            context+="1. Follow PEP 8\n"
            context+="2. Use type hints\n"
            context+="3. Add docstrings\n"
            context+="4. Use context managers (with statement)\n"
            context+="5. Handle exceptions gracefully\n"
            context+="6. Write unit tests\n"
            context+="\n"
            ;;
            
        *)
            context+="### GENERAL PROGRAMMING PRINCIPLES\n"
            context+="1. Write clear, maintainable code\n"
            context+="2. Add comments for complex logic\n"
            context+="3. Follow SOLID principles\n"
            context+="4. Write modular, testable code\n"
            context+="\n"
            ;;
    esac
    
    # Add specific requirements
    context+="## SPECIFIC REQUIREMENTS\n"
    context+="$description\n"
    context+="\n"
    
    context+="## GENERATION INSTRUCTIONS\n"
    context+="1. Write complete, production-ready code\n"
    context+="2. Include proper error handling\n"
    context+="3. Add necessary comments\n"
    context+="4. Follow the project's existing style\n"
    context+="5. Make it modular and reusable\n"
    
    echo -e "$context"
}

# Generate code based on patterns
suggest_code_from_pattern() {
    local description="$1"
    local language="${2:-bash}"
    
    echo "=== CODE SUGGESTION ==="
    echo "For: $description"
    echo "Language: $language"
    echo ""
    
    # Common patterns
    if [[ "$description" == *"function"* ]] || [[ "$description" == *"utility"* ]]; then
        case "$language" in
            bash)
                echo "#!/usr/bin/env bash"
                echo "set -euo pipefail"
                echo ""
                echo "# $(echo "$description" | sed 's/function //;s/utility //')"
                echo "# Generated: $(date)"
                echo ""
                echo "main() {"
                echo "    local input=\"\${1:-}\""
                echo "    "
                echo "    # Validate input"
                echo "    if [[ -z \"\$input\" ]]; then"
                echo "        echo \"Error: Input required\" >&2"
                echo "        echo \"Usage: \$0 <input>\" >&2"
                echo "        return 1"
                echo "    fi"
                echo "    "
                echo "    # Process input"
                echo "    echo \"Processing: \$input\""
                echo "    "
                echo "    # Add your logic here"
                echo "    "
                echo "    echo \"Done\""
                echo "}"
                echo ""
                echo "# Helper functions"
                echo "validate_input() {"
                echo "    local input=\"\$1\""
                echo "    # Add validation logic"
                echo "    [[ -n \"\$input\" ]]"
                echo "}"
                echo ""
                echo "# Main execution"
                echo "if [[ \"\${BASH_SOURCE[0]}\" == \"\${0}\" ]]; then"
                echo "    main \"\$@\""
                echo "fi"
                ;;
                
            python)
                echo "#!/usr/bin/env python3"
                echo "\"\"\""
                echo "$(echo "$description" | sed 's/function //;s/utility //')"
                echo "\"\"\""
                echo ""
                echo "import sys"
                echo "from typing import Optional"
                echo ""
                echo ""
                echo "def main(input_data: Optional[str] = None) -> int:"
                echo "    \"\"\"Main function.\"\"\""
                echo "    if not input_data:"
                echo "        print(\"Error: Input required\", file=sys.stderr)"
                echo "        print(f\"Usage: {sys.argv[0]} <input>\", file=sys.stderr)"
                echo "        return 1"
                echo "    "
                echo "    print(f\"Processing: {input_data}\")"
                echo "    "
                echo "    # Add your logic here"
                echo "    "
                echo "    print(\"Done\")"
                echo "    return 0"
                echo ""
                echo ""
                echo "def validate_input(input_data: str) -> bool:"
                echo "    \"\"\"Validate input data.\"\"\""
                echo "    return bool(input_data.strip())"
                echo ""
                echo ""
                echo "if __name__ == \"__main__\":"
                echo "    input_arg = sys.argv[1] if len(sys.argv) > 1 else None"
                echo "    sys.exit(main(input_arg))"
                ;;
        esac
        
    elif [[ "$description" == *"script"* ]] || [[ "$description" == *"tool"* ]]; then
        echo "# TODO: Implement based on specific requirements"
        echo "# Use 'orchat suggest' for specific patterns"
        
    else
        echo "# Code generation for: $description"
        echo "#"
        echo "# Steps to implement:"
        echo "# 1. Analyze requirements"
        echo "# 2. Design modular structure"
        echo "# 3. Implement with error handling"
        echo "# 4. Add tests"
        echo "# 5. Document usage"
    fi
}

# Generate test code
generate_tests() {
    local target_file="$1"
    local language="${2:-}"
    
    [[ -z "$language" ]] && language=$(detect_language "$target_file")
    
    echo "=== TEST GENERATION ==="
    echo "For: $target_file"
    echo "Language: $language"
    echo ""
    
    case "$language" in
        bash)
            echo "#!/usr/bin/env bash"
            echo "set -euo pipefail"
            echo ""
            echo "# Tests for $(basename "$target_file")"
            echo ""
            echo "source \"$target_file\""
            echo ""
            echo "test_function() {"
            echo "    echo \"Testing...\""
            echo "    "
            echo "    # Add test cases"
            echo "    "
            echo "    echo \"All tests passed\""
            echo "    return 0"
            echo "}"
            echo ""
            echo "# Run tests"
            echo "if [[ \"\${BASH_SOURCE[0]}\" == \"\${0}\" ]]; then"
            echo "    test_function"
            echo "fi"
            ;;
            
        python)
            echo "#!/usr/bin/env python3"
            echo "\"\"\"Tests for $(basename "$target_file").\"\"\""
            echo ""
            echo "import unittest"
            echo "import sys"
            echo "import os"
            echo ""
            echo "sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))"
            echo ""
            echo "class Test$(basename "$target_file" .py | sed 's/^test_//;s/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' | sed 's/ //g')(unittest.TestCase):"
            echo "    \"\"\"Test cases.\"\"\""
            echo ""
            echo "    def setUp(self):"
            echo "        \"\"\"Set up test fixtures.\"\"\""
            echo "        pass"
            echo ""
            echo "    def tearDown(self):"
            echo "        \"\"\"Tear down test fixtures.\"\"\""
            echo "        pass"
            echo ""
            echo "    def test_example(self):"
            echo "        \"\"\"Example test.\"\"\""
            echo "        self.assertTrue(True)"
            echo ""
            echo ""
            echo "if __name__ == \"__main__\":"
            echo "    unittest.main()"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        "context")
            generate_code_context "${2:-"create a utility function"}" "${3:-bash}"
            ;;
        "suggest")
            suggest_code_from_pattern "${2:-"function"}" "${3:-bash}"
            ;;
        "tests")
            generate_tests "${2:-$0}" "${3:-}"
            ;;
        "test")
            echo "Testing code generation..."
            generate_code_context "test function" "bash" | head -20
            ;;
        *)
            echo "Usage: $0 {context <desc> [lang]|suggest <desc> [lang]|tests <file> [lang]|test}"
            ;;
    esac
fi
