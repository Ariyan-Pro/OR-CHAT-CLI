#!/usr/bin/env bash
set -euo pipefail

# Interactive model browser with filtering
browse_models() {
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        echo "No API key set. Use --setup first."
        return 1
    fi
    
    echo "🌐 Fetching models from OpenRouter..."
    
    # Fetch models
    models_json="/tmp/orchat_models_$$.json"
    curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" \
         "https://openrouter.ai/api/v1/models" > "$models_json"
    
    if [[ ! -s "$models_json" ]] || ! jq -e '.data' "$models_json" >/dev/null 2>&1; then
        echo "Failed to fetch models. Check API key."
        rm -f "$models_json"
        return 1
    fi
    
    # Interactive filter menu
    while true; do
        clear
        echo "========================================"
        echo "          ORCHAT MODEL BROWSER          "
        echo "========================================"
        echo ""
        echo "Filters:"
        echo "  1. Show all models"
        echo "  2. Free models only"
        echo "  3. Paid models only"
        echo "  4. Search by name"
        echo "  5. Sort by context length"
        echo "  6. Sort by price (cheapest first)"
        echo ""
        echo "  0. Exit"
        echo ""
        echo "========================================"
        echo -n "Select option: "
        
        read -r choice
        
        case "$choice" in
            1)
                echo ""
                echo "=== ALL MODELS ==="
                jq -r '.data[] | "\(.id) | \(.context_length) ctx | Prompt: $\(.pricing.prompt)/1M | Comp: $\(.pricing.completion)/1M"' "$models_json" \
                    | head -30
                ;;
            2)
                echo ""
                echo "=== FREE MODELS ==="
                jq -r '.data[] | select(.pricing.prompt == "0" and .pricing.completion == "0") | "\(.id) (\(.context_length) ctx)"' "$models_json" \
                    | head -20
                ;;
            3)
                echo ""
                echo "=== PAID MODELS ==="
                jq -r '.data[] | select(.pricing.prompt != "0" or .pricing.completion != "0") | "\(.id) | Prompt: $\(.pricing.prompt)/1M | Comp: $\(.pricing.completion)/1M"' "$models_json" \
                    | head -20
                ;;
            4)
                echo -n "Search for: "
                read -r query
                echo ""
                echo "=== SEARCH RESULTS: '$query' ==="
                jq -r --arg q "$query" '.data[] | select(.id | contains($q)) | "\(.id) | \(.context_length) ctx | Prompt: $\(.pricing.prompt)/1M | Comp: $\(.pricing.completion)/1M"' "$models_json" \
                    | head -20
                ;;
            5)
                echo ""
                echo "=== SORTED BY CONTEXT LENGTH ==="
                jq -r '.data[] | "\(.context_length) ctx | \(.id) | Prompt: $\(.pricing.prompt)/1M | Comp: $\(.pricing.completion)/1M"' "$models_json" \
                    | sort -rn | head -20
                ;;
            6)
                echo ""
                echo "=== SORTED BY PRICE (cheapest first) ==="
                jq -r '.data[] | "Prompt: $\(.pricing.prompt) | Comp: $\(.pricing.completion) | \(.id) | \(.context_length) ctx"' "$models_json" \
                    | sort -n | head -20
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        
        echo ""
        echo "========================================"
        echo "Press Enter to continue..."
        read -r
    done
    
    rm -f "$models_json"
    echo ""
    echo "Tip: Use a model with: orchat -m \"model_id\" \"your prompt\""
}

# Quick model list (non-interactive)
quick_model_list() {
    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        echo "Set API key first with: orchat --setup"
        return 1
    fi
    
    models=$(curl -s -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        "https://openrouter.ai/api/v1/models" | \
        jq -r '.data[0:10][] | "\(.id) (\(.context_length) ctx)"' 2>/dev/null)
    
    if [[ -n "$models" ]]; then
        echo "=== TOP 10 MODELS ==="
        echo "$models"
        echo ""
        echo "For full list: orchat --models"
    else
        echo "Could not fetch models."
    fi
}
