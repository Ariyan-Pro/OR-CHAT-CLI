#!/usr/bin/env bash
set -euo pipefail

# Robust SSE/chunk handler with Python validation
handle_stream_chunks() {
    local buffer=""
    local in_chunk=false
    local chunk_buffer=""
    
    # Use Python for robust JSON parsing
    python3 -c "
import sys, json

buffer = ''
for line in sys.stdin:
    line = line.rstrip('\\n')
    
    # Skip empty lines (keep-alive)
    if not line:
        continue
    
    # Handle SSE format (data: ...)
    if line.startswith('data: '):
        line = line[6:]
    
    # Skip [DONE] sentinel
    if line.strip() == '[DONE]':
        sys.stdout.write('\\n')
        sys.stdout.flush()
        break
    
    # Try to parse as JSON
    try:
        data = json.loads(line)
        
        # Extract content from different possible locations
        content = None
        
        # OpenAI format
        if 'choices' in data and len(data['choices']) > 0:
            choice = data['choices'][0]
            if 'delta' in choice and 'content' in choice['delta']:
                content = choice['delta']['content']
            elif 'text' in choice:
                content = choice['text']
            elif 'message' in choice and 'content' in choice['message']:
                content = choice['message']['content']
        
        # Generic content field
        if not content and 'content' in data:
            content = data['content']
        
        # Error handling
        if not content and 'error' in data:
            error_msg = data['error'].get('message', str(data['error']))
            sys.stderr.write(f'[ERROR] {error_msg}\\n')
            continue
        
        # Output content if found
        if content:
            sys.stdout.write(content)
            sys.stdout.flush()
            
    except json.JSONDecodeError:
        # Partial JSON - buffer and retry
        buffer += line
        try:
            data = json.loads(buffer)
            # If we get here, buffer was complete
            if 'choices' in data and len(data['choices']) > 0:
                choice = data['choices'][0]
                if 'delta' in choice and 'content' in choice['delta']:
                    content = choice['delta']['content']
                    if content:
                        sys.stdout.write(content)
                        sys.stdout.flush()
            buffer = ''
        except:
            # Still invalid, continue buffering
            pass
    except Exception as e:
        sys.stderr.write(f'[ERROR] Parse error: {e}\\n')
" 2>/dev/null || {
    # Python fallback - basic line processing
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and keep-alives
        [[ -z "$line" ]] && continue
        
        # Handle SSE format
        line="${line#data: }"
        
        # Skip [DONE]
        [[ "$line" == "[DONE]" ]] && echo "" && break
        
        # Try jq extraction
        chunk_text=$(printf '%s' "$line" | jq -r '.choices[0].delta.content // .choices[0].text // ""' 2>/dev/null || true)
        if [[ -n "$chunk_text" ]]; then
            printf '%s' "$chunk_text"
        fi
    done
}
}

# New function: Validate stream response
validate_stream_chunk() {
    local chunk="$1"
    
    # Use Python to validate JSON chunk
    python3 -c "
import json, sys
chunk = '''$chunk'''
try:
    data = json.loads(chunk)
    print('VALID')
except json.JSONDecodeError as e:
    print(f'INVALID: {e}')
except Exception as e:
    print(f'ERROR: {e}')
" 2>/dev/null || echo "UNKNOWN"
}

# Function to test streaming endpoint
test_streaming() {
    echo "Testing streaming connection..."
    
    local test_payload='{
      "model": "openai/gpt-3.5-turbo",
      "messages": [{"role": "user", "content": "Say TEST"}],
      "temperature": 0.7,
      "stream": true
    }'
    
    timeout 5 curl --no-buffer -sS -X POST "$ORCHAT_API_URL" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$test_payload" 2>/dev/null | \
        head -5 | while read -r line; do
            echo "Chunk: ${line:0:50}..."
        done
    
    echo "Streaming test complete"
}
