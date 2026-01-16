#!/usr/bin/env bash
#
# PATCH: Add deterministic mode to ORCHAT
# Phase 4.3: Deterministic mode implementation
#

set -euo pipefail

# File to patch
ORCHAT_BIN="./bin/orchat"
PATCH_FILE="./phase4/deterministic.patch"

# Create the patch
cat > "$PATCH_FILE" << 'PATCH'
--- a/bin/orchat
+++ b/bin/orchat
@@ -15,6 +15,7 @@
   --model MODEL       Model to use (default: gemini-1.5-pro)
   --temperature TEMP  Temperature for generation (0.0-1.0, default: 0.7)
   --max-tokens N      Maximum tokens to generate (default: 1000)
+  --deterministic     Enable deterministic mode (temperature=0.0, seed=42)
   --raw               Output raw JSON response
   --debug             Enable debug output
   --help              Show this help message
@@ -35,6 +36,7 @@
   local model="gemini-1.5-pro"
   local temperature="0.7"
   local max_tokens="1000"
+  local deterministic=false
   local raw_output=false
   local debug=false
   
@@ -46,6 +48,9 @@
         --model)
           model="$2"
           shift 2 ;;
+        --deterministic)
+          deterministic=true
+          shift ;;
         --temperature)
           temperature="$2"
           shift 2 ;;
@@ -77,6 +82,12 @@
     shift
   done
   
+  # Apply deterministic mode
+  if [[ "$deterministic" == "true" ]]; then
+    temperature="0.0"
+    echo "# DETERMINISTIC MODE: temperature=0.0" >&2
+  fi
+  
   # Validate temperature
   if ! [[ "$temperature" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
      (( $(echo "$temperature < 0.0 || $temperature > 1.0" | bc -l 2>/dev/null || echo 1) )); then
@@ -122,6 +133,9 @@
     "maxOutputTokens": $max_tokens
   }
   
+  # Add seed for deterministic mode if supported by API
+  [[ "$deterministic" == "true" ]] && jq '.seed = 42' <<< "$payload" > tmp_payload.json && mv tmp_payload.json payload.json
+  
   # Make API request
   if [[ "$debug" == "true" ]]; then
     echo "DEBUG: Request payload:" >&2
PATCH

# Apply the patch
if patch -p1 --dry-run < "$PATCH_FILE" &>/dev/null; then
    patch -p1 < "$PATCH_FILE"
    Write-Host "✅ Deterministic mode patch applied successfully" -ForegroundColor Green
else
    Write-Host "⚠️  Patch may not apply cleanly, manual review needed" -ForegroundColor Yellow
    Write-Host "💡 Patch file created at: $PATCH_FILE" -ForegroundColor White
fi

# Create test script for deterministic mode
cat > "test_deterministic.sh" << 'TEST'
#!/usr/bin/env bash
# Test script for deterministic mode

echo "Testing deterministic mode..."
echo "============================="

# Test 1: Regular mode (should have variation)
echo -e "\n1. Regular mode (temperature=0.7):"
for i in {1..3}; do
    echo "Run $i:" $(./bin/orchat --temperature 0.7 "Say hello" 2>/dev/null | head -c 20)
done

# Test 2: Deterministic mode (should be identical)
echo -e "\n2. Deterministic mode (--deterministic):"
for i in {1..3}; do
    echo "Run $i:" $(./bin/orchat --deterministic "Say hello" 2>/dev/null | head -c 20)
done

# Test 3: Temperature 0.0 (manual deterministic)
echo -e "\n3. Manual temperature=0.0:"
for i in {1..3}; do
    echo "Run $i:" $(./bin/orchat --temperature 0.0 "Say hello" 2>/dev/null | head -c 20)
done

echo -e "\n✅ Deterministic mode test completed"
TEST

chmod +x test_deterministic.sh
Write-Host "✅ Created deterministic mode test script" -ForegroundColor Green
