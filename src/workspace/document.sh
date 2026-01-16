#!/usr/bin/env bash
# document.sh - Intelligent documentation generation
# 50+ years: Documentation should explain why, not just what

# Load workspace modules
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/analyze.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/analyze.sh"
fi

# Generate documentation for a file
generate_docs() {
    local file="$1"
    local format="${2:-markdown}"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; return 1; }
    
    local language
    language=$(detect_language "$file")
    local basename
    basename=$(basename "$file")
    
    echo "=== DOCUMENTATION GENERATION ==="
    echo "File: $file"
    echo "Language: $language"
    echo "Format: $format"
    echo ""
    
    case "$format" in
        markdown)
            echo "# $basename"
            echo ""
            echo "## Overview"
            echo ""
            echo "This file contains code for:"
            echo "- [Purpose description]"
            echo "- [Key functionality]"
            echo ""
            
            case "$language" in
                bash)
                    echo "## Functions"
                    echo ""
                    local functions
                    functions=$(grep '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()[[:space:]]*{' "$file" 2>/dev/null || true)
                    
                    if [[ -n "$functions" ]]; then
                        echo "$functions" | while read -r line; do
                            local func_name
                            func_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*()[[:space:]]*{.*//')
                            echo "### $func_name()"
                            echo ""
                            echo "**Purpose:** [Describe what this function does]"
                            echo ""
                            echo "**Parameters:**"
                            echo "- \`\$1\`: [Description]"
                            echo "- \`\$2\`: [Description] (if applicable)"
                            echo ""
                            echo "**Returns:**"
                            echo "- Exit code 0 on success"
                            echo "- Non-zero on error"
                            echo ""
                            echo "**Example:**"
                            echo "\`\`\`bash"
                            echo "# $func_name \"argument\""
                            echo "\`\`\`"
                            echo ""
                        done
                    else
                        echo "This is a procedural script without defined functions."
                        echo ""
                        echo "## Usage"
                        echo "\`\`\`bash"
                        echo "./$basename [arguments]"
                        echo "\`\`\`"
                    fi
                    
                    echo "## Configuration"
                    echo ""
                    echo "### Environment Variables"
                    echo "- \`VARIABLE_NAME\`: [Description]"
                    echo ""
                    echo "### Dependencies"
                    echo "- Required commands: [list commands]"
                    ;;
                    
                python)
                    echo "## Classes and Functions"
                    echo ""
                    # Extract classes
                    local classes
                    classes=$(grep '^[[:space:]]*class[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null || true)
                    
                    if [[ -n "$classes" ]]; then
                        echo "### Classes"
                        echo ""
                        echo "$classes" | while read -r line; do
                            local class_name
                            class_name=$(echo "$line" | sed 's/^[[:space:]]*class[[:space:]]*//;s/:.*//')
                            echo "#### $class_name"
                            echo ""
                            echo "**Purpose:** [Describe class purpose]"
                            echo ""
                            echo "**Methods:**"
                            # Get methods for this class
                            echo "- \`method_name()\`: [Description]"
                            echo ""
                        done
                    fi
                    
                    # Extract functions
                    local functions
                    functions=$(grep '^[[:space:]]*def[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null || true)
                    
                    if [[ -n "$functions" ]]; then
                        echo "### Functions"
                        echo ""
                        echo "$functions" | while read -r line; do
                            local func_name
                            func_name=$(echo "$line" | sed 's/^[[:space:]]*def[[:space:]]*//;s/(.*//')
                            echo "#### $func_name()"
                            echo ""
                            echo "**Purpose:** [Describe function purpose]"
                            echo ""
                            echo "**Parameters:**"
                            echo "- \`param\`: [Description]"
                            echo ""
                            echo "**Returns:**"
                            echo "- [Return type]: [Description]"
                            echo ""
                            echo "**Example:**"
                            echo "\`\`\`python"
                            echo "result = $func_name(argument)"
                            echo "\`\`\`"
                            echo ""
                        done
                    fi
                    ;;
            esac
            
            echo "## Examples"
            echo ""
            echo "### Basic Usage"
            echo "\`\`\`"
            echo "# Add example command"
            echo "\`\`\`"
            echo ""
            echo "### Advanced Usage"
            echo "\`\`\`"
            echo "# Add advanced example"
            echo "\`\`\`"
            echo ""
            echo "## Troubleshooting"
            echo ""
            echo "| Error | Solution |"
            echo "|-------|----------|"
            echo "| Common error 1 | Fix 1 |"
            echo "| Common error 2 | Fix 2 |"
            ;;
            
        *)
            echo "Unsupported format: $format"
            echo "Supported formats: markdown"
            return 1
            ;;
    esac
}

# Generate README from project structure
generate_readme() {
    local project_name="${1:-$(basename "$(pwd)")}"
    
    echo "# $project_name"
    echo ""
    echo "## Overview"
    echo ""
    echo "[Brief description of the project]"
    echo ""
    echo "## Features"
    echo ""
    echo "- Feature 1"
    echo "- Feature 2"
    echo "- Feature 3"
    echo ""
    echo "## Installation"
    echo ""
    echo "\`\`\`bash"
    echo "# Installation commands"
    echo "\`\`\`"
    echo ""
    echo "## Usage"
    echo ""
    echo "### Basic Usage"
    echo "\`\`\`bash"
    echo "# Basic command"
    echo "\`\`\`"
    echo ""
    echo "### Advanced Usage"
    echo "\`\`\`bash"
    echo "# Advanced command"
    echo "\`\`\`"
    echo ""
    echo "## Project Structure"
    echo ""
    echo "```"
    find . -maxdepth 3 -type f -name "*.sh" -o -name "*.py" -o -name "*.md" -o -name "*.json" \
        ! -path "./.*" ! -path "*/node_modules/*" | sort | head -20
    echo "```"
    echo ""
    echo "## Documentation"
    echo ""
    echo "### Core Modules"
    echo ""
    echo "| Module | Purpose |"
    echo "|--------|---------|"
    echo "| module1.sh | Core functionality |"
    echo "| module2.py | Supporting logic |"
    echo ""
    echo "## Development"
    echo ""
    echo "### Prerequisites"
    echo ""
    echo "- Requirement 1"
    echo "- Requirement 2"
    echo ""
    echo "### Building"
    echo ""
    echo "\`\`\`bash"
    echo "# Build commands"
    echo "\`\`\`"
    echo ""
    echo "### Testing"
    echo ""
    echo "\`\`\`bash"
    echo "# Test commands"
    echo "\`\`\`"
    echo ""
    echo "## License"
    echo ""
    echo "[License information]"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        "file")
            generate_docs "${2:-$0}" "${3:-markdown}"
            ;;
        "readme")
            generate_readme "${2:-}"
            ;;
        "test")
            echo "Testing documentation generation..."
            generate_docs "$0" "markdown" | head -40
            ;;
        *)
            echo "Usage: $0 {file <path> [format]|readme [name]|test}"
            ;;
    esac
fi
