#!/usr/bin/env bash
# workspace.sh - ORCHAT Workspace Awareness Module
# Phase 5.0 Step 1: Foundation before intelligence

source "$(dirname "$0")/workspace/detect_root.sh"
source "$(dirname "$0")/workspace/ignore.sh"
source "$(dirname "$0")/workspace/scan_files.sh"
source "$(dirname "$0")/workspace/summarize.sh"

workspace_status() {
    # Time the operation for performance tracking
    local start_time
    start_time=$(date +%s%N)
    
    local summary
    summary=$(summarize_workspace "$(pwd)")
    
    local end_time
    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    echo "$summary"
    echo ""
    echo "[DEBUG] Workspace analysis completed in ${duration_ms}ms"
}

# If called directly, run status
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    workspace_status "$@"
fi

################################################################
# PHASE 5.0 STEP 4: AI ASSISTANCE
################################################################

# Load the AI assistant
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/workspace/assist.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/workspace/assist.sh"
    
    workspace_assist() {
        local query="$1"
        local max_files="${2:-3}"
        
        if [[ -z "$query" ]]; then
            echo "Usage: workspace_assist <query> [max_files]"
            echo "Examples:"
            echo "  workspace_assist 'help with bash functions'"
            echo "  workspace_assist 'explain configuration' 5"
            echo "  workspace_assist 'review my code'"
            return 1
        fi
        
        generate_ai_context_flush "$query" "$max_files"
    }
    
    workspace_suggest() {
        local pattern="$1"
        local language="${2:-bash}"
        
        if [[ -z "$pattern" ]]; then
            echo "Usage: workspace_suggest <pattern> [language]"
            echo "Examples:"
            echo "  workspace_suggest 'function'"
            echo "  workspace_suggest 'error handling' python"
            echo "  workspace_suggest 'loop' bash"
            return 1
        fi
        
        suggest_code "$pattern" "$language"
    }
    
    workspace_review() {
        local file="${1}"
        
        if [[ -z "$file" ]]; then
            echo "Usage: workspace_review <file>"
            echo "Example: workspace_review src/workspace.sh"
            return 1
        fi
        
        if [[ ! -f "$file" ]]; then
            echo "File not found: $file"
            return 1
        fi
        
        review_code "$file"
    }
    
    workspace_explain() {
        local file="${1}"
        local section="${2:-all}"
        
        if [[ -z "$file" ]]; then
            echo "Usage: workspace_explain <file> [section]"
            echo "Examples:"
            echo "  workspace_explain src/workspace.sh"
            echo "  workspace_explain README.md header"
            return 1
        fi
        
        if [[ ! -f "$file" ]]; then
            echo "File not found: $file"
            return 1
        fi
        
        explain_code "$file" "$section"
    }
else
    # Fallback if assist.sh isn't available
    workspace_assist() {
        echo "[ERROR] AI assistance module not available"
        return 1
    }
    
    workspace_suggest() {
        echo "[ERROR] Code suggestions not available"
        return 1
    }
    
    workspace_review() {
        echo "[ERROR] Code review not available"
        return 1
    }
    
    workspace_explain() {
        echo "[ERROR] Code explanation not available"
        return 1
    }
fi

################################################################
# PHASE 6.0: ADVANCED AI INTEGRATION
################################################################

# Load code generation module
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/workspace/generate.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/workspace/generate.sh"
    
    workspace_generate() {
        local description="$1"
        local language="${2:-bash}"
        
        if [[ -z "$description" ]]; then
            echo "Usage: workspace_generate <description> [language]"
            echo "Examples:"
            echo "  workspace_generate 'function to process files'"
            echo "  workspace_generate 'utility script' bash"
            echo "  workspace_generate 'data processor' python"
            return 1
        fi
        
        suggest_code_from_pattern "$description" "$language"
    }
    
    workspace_generate_context() {
        local description="$1"
        local language="${2:-bash}"
        local max_context="${3:-5000}"
        
        if [[ -z "$description" ]]; then
            echo "Usage: workspace_generate_context <description> [language] [max_context]"
            return 1
        fi
        
        generate_code_context "$description" "$language" "$max_context"
    }
    
    workspace_generate_tests() {
        local file="$1"
        local language="${2:-}"
        
        if [[ -z "$file" ]]; then
            echo "Usage: workspace_generate_tests <file> [language]"
            echo "Example: workspace_generate_tests src/workspace.sh"
            return 1
        fi
        
        if [[ ! -f "$file" ]]; then
            echo "File not found: $file"
            return 1
        fi
        
        generate_tests "$file" "$language"
    }
else
    workspace_generate() {
        echo "[ERROR] Code generation module not available"
        return 1
    }
    
    workspace_generate_context() {
        echo "[ERROR] Code context module not available"
        return 1
    }
    
    workspace_generate_tests() {
        echo "[ERROR] Test generation module not available"
        return 1
    }
fi

# Load refactoring module
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/workspace/refactor.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/workspace/refactor.sh"
    
    workspace_refactor_analyze() {
        local file="$1"
        
        if [[ -z "$file" ]]; then
            echo "Usage: workspace_refactor_analyze <file>"
            echo "Example: workspace_refactor_analyze src/workspace.sh"
            return 1
        fi
        
        if [[ ! -f "$file" ]]; then
            echo "File not found: $file"
            return 1
        fi
        
        analyze_refactoring "$file"
    }
    
    workspace_refactor_suggest() {
        local pattern="$1"
        local language="${2:-bash}"
        
        if [[ -z "$pattern" ]]; then
            echo "Usage: workspace_refactor_suggest <pattern> [language]"
            echo "Examples:"
            echo "  workspace_refactor_suggest 'extract function'"
            echo "  workspace_refactor_suggest 'rename variable' python"
            echo "  workspace_refactor_suggest 'simplify conditionals'"
            return 1
        fi
        
        suggest_refactoring "$pattern" "$language"
    }
else
    workspace_refactor_analyze() {
        echo "[ERROR] Refactoring module not available"
        return 1
    }
    
    workspace_refactor_suggest() {
        echo "[ERROR] Refactoring suggestions not available"
        return 1
    }
fi

# Load documentation module
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/workspace/document.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/workspace/document.sh"
    
    workspace_document_file() {
        local file="$1"
        local format="${2:-markdown}"
        
        if [[ -z "$file" ]]; then
            echo "Usage: workspace_document_file <file> [format]"
            echo "Example: workspace_document_file src/workspace.sh"
            echo "         workspace_document_file README.md markdown"
            return 1
        fi
        
        if [[ ! -f "$file" ]]; then
            echo "File not found: $file"
            return 1
        fi
        
        generate_docs "$file" "$format"
    }
    
    workspace_document_readme() {
        local project_name="$1"
        
        generate_readme "$project_name"
    }
else
    workspace_document_file() {
        echo "[ERROR] Documentation module not available"
        return 1
    }
    
    workspace_document_readme() {
        echo "[ERROR] README generation not available"
        return 1
    }
fi

################################################################
# PHASE 7.0: ENTERPRISE FEATURES
################################################################

# Load enterprise modules
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/enterprise/packaging.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/enterprise/packaging.sh"
    
    workspace_package_deb() {
        local build_dir="${1:-./build/deb}"
        local output_dir="${2:-./dist}"
        
        create_deb_package "$build_dir" "$output_dir"
    }
    
    workspace_package_docker() {
        local dockerfile="${1:-./Dockerfile.enterprise}"
        local tag="${2:-orchat:enterprise-latest}"
        
        create_docker_image "$dockerfile" "$tag"
    }
    
    workspace_package_installer() {
        local output_file="${1:-./install-orchat.sh}"
        
        create_install_script "$output_file"
    }
else
    workspace_package_deb() {
        echo "[ERROR] Enterprise packaging module not available"
        return 1
    }
    
    workspace_package_docker() {
        echo "[ERROR] Docker packaging not available"
        return 1
    }
    
    workspace_package_installer() {
        echo "[ERROR] Installer generation not available"
        return 1
    }
fi

# Load observability module
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/enterprise/observability.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/enterprise/observability.sh"
    
    workspace_metrics_init() {
        init_metrics
    }
    
    workspace_metrics_prometheus() {
        get_prometheus_metrics
    }
    
    workspace_metrics_json() {
        get_json_metrics
    }
    
    workspace_health_check() {
        health_check
    }
    
    workspace_metrics_cleanup() {
        cleanup_metrics "${1:-}"
    }
    
    workspace_metrics_server() {
        start_metrics_server "${1:-9090}"
    }
else
    workspace_metrics_init() {
        echo "[ERROR] Observability module not available"
        return 1
    }
    
    workspace_metrics_prometheus() {
        echo "[ERROR] Metrics not available"
        return 1
    }
    
    workspace_health_check() {
        echo "[ERROR] Health check not available"
        return 1
    }
fi

# Enterprise mode
workspace_enterprise() {
    echo "=== ORCHAT ENTERPRISE MODE ==="
    echo "Version: 0.7.0"
    echo ""
    echo "Available enterprise commands:"
    echo ""
    echo "Packaging:"
    echo "  package-deb [build] [dist]    - Create DEB package"
    echo "  package-docker [file] [tag]   - Create Docker image"
    echo "  package-installer [file]      - Create installation script"
    echo ""
    echo "Observability:"
    echo "  metrics-init                  - Initialize metrics"
    echo "  metrics-prometheus            - Export Prometheus metrics"
    echo "  metrics-json                  - Export JSON metrics"
    echo "  health-check                  - System health check"
    echo "  metrics-cleanup [days]        - Cleanup old metrics"
    echo "  metrics-server [port]         - Start metrics server"
    echo ""
    echo "Usage: orchat <command>"
}
