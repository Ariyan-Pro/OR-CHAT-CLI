#!/bin/bash
# ORCHAT Context Window Optimizer - Advanced Features Module 2
# Workstream 3: Context Management

# Maximum context window size (in tokens)
MAX_CONTEXT_SIZE=${ORCHAT_MAX_CONTEXT:-4000}
OPTIMIZATION_STRATEGY=${ORCHAT_OPTIMIZATION_STRATEGY:-"smart"}  # smart, aggressive, conservative

# Initialize context optimizer
init_context_optimizer() {
    echo "Context optimizer initialized (strategy: $OPTIMIZATION_STRATEGY, max: ${MAX_CONTEXT_SIZE}t)"
}

# Estimate token count (simplified)
estimate_tokens() {
    local text="$1"
    # Rough estimate: 1 token ≈ 4 characters for English text
    local chars=${#text}
    echo $(( (chars + 3) / 4 ))
}

# Optimize messages for context window
optimize_context() {
    local messages_json="$1"
    local current_tokens=$2
    
    if [[ $current_tokens -le $MAX_CONTEXT_SIZE ]]; then
        echo "$messages_json"
        return 0
    fi
    
    echo "Optimizing context: ${current_tokens}t > ${MAX_CONTEXT_SIZE}t" >&2
    
    # Use Python for complex JSON optimization
    python3 -c "
import json, sys

messages = json.loads('''$messages_json''')
current_tokens = $current_tokens
max_tokens = $MAX_CONTEXT_SIZE
strategy = '$OPTIMIZATION_STRATEGY'

# Calculate token usage for each message
for msg in messages:
    msg['estimated_tokens'] = len(msg.get('content', '')) // 4

# Optimization strategies
if strategy == 'aggressive':
    # Remove oldest messages first
    while sum(m['estimated_tokens'] for m in messages) > max_tokens and len(messages) > 1:
        removed = messages.pop(0)
        print(f\"Removed: {removed.get('role', 'unknown')} - {removed['estimated_tokens']}t\", file=sys.stderr)
        
elif strategy == 'conservative':
    # Try to keep as much as possible, compress if needed
    if sum(m['estimated_tokens'] for m in messages) > max_tokens:
        # Keep system message and last user/assistant exchange
        if len(messages) > 3:
            system_msg = messages[0] if messages[0].get('role') == 'system' else None
            last_exchange = messages[-2:]  # Last user and assistant messages
            
            messages = []
            if system_msg:
                messages.append(system_msg)
            messages.extend(last_exchange)
            
elif strategy == 'smart':
    # Default smart strategy
    total_tokens = sum(m['estimated_tokens'] for m in messages)
    
    # Priority: system > recent > older
    priorities = []
    for i, msg in enumerate(messages):
        priority = 0
        if msg.get('role') == 'system':
            priority = 100
        elif i >= len(messages) - 4:  # Last 2 exchanges (4 messages)
            priority = 50 - (len(messages) - i)
        else:
            priority = 10 - (len(messages) - i)
        priorities.append(priority)
    
    # Sort by priority and keep highest priority messages
    indexed = list(zip(messages, priorities))
    indexed.sort(key=lambda x: x[1], reverse=True)
    
    kept_messages = []
    kept_tokens = 0
    
    for msg, priority in indexed:
        if kept_tokens + msg['estimated_tokens'] <= max_tokens * 0.9:  # Leave 10% buffer
            kept_messages.append(msg)
            kept_tokens += msg['estimated_tokens']
        else:
            print(f\"Skipped (priority {priority}): {msg.get('role', 'unknown')} - {msg['estimated_tokens']}t\", file=sys.stderr)
    
    # Restore original order for kept messages
    kept_messages.sort(key=lambda x: messages.index(x))
    messages = kept_messages

# Remove estimation field before returning
for msg in messages:
    if 'estimated_tokens' in msg:
        del msg['estimated_tokens']

print(json.dumps(messages))
"
}

# Summarize long context
summarize_context() {
    local messages_json="$1"
    
    python3 -c "
import json, sys

messages = json.loads('''$messages_json''')

# Simple summarization logic
summary = []
total_messages = len(messages)

if total_messages > 10:
    # Keep first and last few messages, summarize middle
    summary.append(messages[0])  # System message
    summary.append({
        'role': 'system',
        'content': f'[Context Summary: {total_messages - 4} messages summarized] Previous conversation contained approximately {total_messages - 4} exchanges about various topics.'
    })
    summary.extend(messages[-3:])  # Last exchange
else:
    summary = messages

print(json.dumps(summary))
"
}

# Batch optimize multiple contexts
batch_optimize() {
    local contexts_dir="$1"
    local output_dir="$2"
    
    mkdir -p "$output_dir"
    
    for context_file in "$contexts_dir"/*.json; do
        if [[ -f "$context_file" ]]; then
            local filename=$(basename "$context_file")
            local messages=$(cat "$context_file")
            local estimated_tokens=$(estimate_tokens "$messages")
            
            if [[ $estimated_tokens -gt $MAX_CONTEXT_SIZE ]]; then
                echo "Optimizing $filename: ${estimated_tokens}t"
                optimized=$(optimize_context "$messages" "$estimated_tokens")
                echo "$optimized" > "$output_dir/$filename"
            else
                cp "$context_file" "$output_dir/$filename"
            fi
        fi
    done
    
    echo "Batch optimization complete: $output_dir"
}

# Context analysis report
analyze_context() {
    local messages_json="$1"
    
    python3 -c "
import json, sys
from datetime import datetime

messages = json.loads('''$messages_json''')

print(\"=== CONTEXT ANALYSIS ===\")
print(f\"Total Messages: {len(messages)}\")

roles = {}
for msg in messages:
    role = msg.get('role', 'unknown')
    roles[role] = roles.get(role, 0) + 1

print(\"\\nMessage Distribution:\")
for role, count in roles.items():
    print(f\"  {role}: {count}\")

total_chars = sum(len(msg.get('content', '')) for msg in messages)
estimated_tokens = total_chars // 4
print(f\"\\nEstimated Tokens: {estimated_tokens}\")
print(f\"Context Window Usage: {estimated_tokens}/$MAX_CONTEXT_SIZE ({estimated_tokens*100/$MAX_CONTEXT_SIZE:.1f}%)\")

if 'timestamp' in messages[-1]:
    try:
        last_msg_time = datetime.fromisoformat(messages[-1]['timestamp'].replace('Z', '+00:00'))
        first_msg_time = datetime.fromisoformat(messages[0]['timestamp'].replace('Z', '+00:00'))
        duration = last_msg_time - first_msg_time
        print(f\"\\nConversation Duration: {duration}\")
    except:
        pass
"
}

# Initialize
init_context_optimizer
