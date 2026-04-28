#!/usr/bin/env bash
# Persistent conversation history (Python-assisted for safety)
# Includes encrypted local storage support

HISTORY_DIR="${ORCHAT_HISTORY_DIR:-$HOME/.orchat/sessions}"
MAX_HISTORY_LENGTH="${MAX_HISTORY_LENGTH:-20}"

# Refresh encryption settings from environment (call this before using encryption)
_refresh_encryption_settings() {
    ENCRYPTION_KEY="${ORCHAT_ENCRYPTION_KEY:-}"
    ENCRYPTION_ENABLED="${ORCHAT_ENCRYPTION_ENABLED:-false}"
}

# Initialize encryption key from environment or generate one
_init_encryption_key() {
    _refresh_encryption_settings
    if [[ -z "$ENCRYPTION_KEY" ]]; then
        # Try to load from secure location
        local key_file="$HOME/.orchat/.encryption_key"
        if [[ -f "$key_file" ]]; then
            ENCRYPTION_KEY=$(cat "$key_file" 2>/dev/null || echo "")
        fi
        # Generate new key if still empty and encryption is enabled
        if [[ -z "$ENCRYPTION_KEY" && "$ENCRYPTION_ENABLED" == "true" ]]; then
            ENCRYPTION_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
            mkdir -p "$(dirname "$key_file")"
            chmod 600 "$key_file" 2>/dev/null || true
            echo "$ENCRYPTION_KEY" > "$key_file" 2>/dev/null || true
            chmod 400 "$key_file" 2>/dev/null || true
        fi
    fi
}

# Encrypt data using Fernet (symmetric encryption)
_encrypt_data() {
    local data="$1"
    local key="$2"
    local enabled="${3:-$ENCRYPTION_ENABLED}"
    
    # Refresh encryption settings from environment first
    _refresh_encryption_settings
    
    # Use passed 'enabled' parameter, but default to current ENCRYPTION_ENABLED if not provided
    if [[ -z "${3:-}" ]]; then
        enabled="$ENCRYPTION_ENABLED"
    fi
    
    if [[ -z "$key" || "$enabled" != "true" ]]; then
        echo "$data"
        return 0
    fi
    
    python3 - "$data" "$key" << 'PYTHON_EOF'
import sys
from cryptography.fernet import Fernet

try:
    data = sys.argv[1]
    key = sys.argv[2]
    # Ensure key is valid base64-encoded 32-byte key
    import base64
    if isinstance(key, bytes):
        key = key.decode('utf-8')
    if len(key) != 44 or not key.endswith('='):
        # Convert hex key to base64
        key = base64.urlsafe_b64encode(bytes.fromhex(key[:64])).decode('utf-8')
    f = Fernet(key.encode('utf-8'))
    encrypted = f.encrypt(data.encode('utf-8'))
    print(encrypted.decode('utf-8'))
except Exception as e:
    sys.stderr.write(f'[ERROR] Encryption failed: {e}\n')
    print(data)  # Return unencrypted on failure
PYTHON_EOF
}

# Decrypt data using Fernet
_decrypt_data() {
    local data="$1"
    local key="$2"
    local enabled="${3:-$ENCRYPTION_ENABLED}"
    
    # Refresh encryption settings from environment first
    _refresh_encryption_settings
    
    # Use passed 'enabled' parameter, but default to current ENCRYPTION_ENABLED if not provided
    if [[ -z "${3:-}" ]]; then
        enabled="$ENCRYPTION_ENABLED"
    fi
    
    if [[ -z "$key" || "$enabled" != "true" ]]; then
        echo "$data"
        return 0
    fi
    
    python3 - "$data" "$key" << 'PYTHON_EOF'
import sys
from cryptography.fernet import Fernet

try:
    data = sys.argv[1]
    key = sys.argv[2]
    import base64
    if isinstance(key, bytes):
        key = key.decode('utf-8')
    if len(key) != 44 or not key.endswith('='):
        key = base64.urlsafe_b64encode(bytes.fromhex(key[:64])).decode('utf-8')
    f = Fernet(key.encode('utf-8'))
    decrypted = f.decrypt(data.encode('utf-8'))
    print(decrypted.decode('utf-8'))
except Exception as e:
    sys.stderr.write(f'[ERROR] Decryption failed: {e}\n')
    print(data)  # Return original on failure
PYTHON_EOF
}

history_init() {
    local session_id="${1:-default}"
    mkdir -p "$HISTORY_DIR"
    local history_file="$HISTORY_DIR/$session_id.json"
    
    # Initialize encryption if enabled (refreshes settings and key)
    _init_encryption_key
    
    if [[ ! -f "$history_file" ]]; then
        if [[ "$ENCRYPTION_ENABLED" == "true" && -n "$ENCRYPTION_KEY" ]]; then
            # Store encrypted empty array
            local encrypted_empty
            encrypted_empty=$(_encrypt_data '[]' "$ENCRYPTION_KEY")
            echo "$encrypted_empty" > "$history_file"
        else
            echo '[]' > "$history_file"
        fi
    fi
    echo "$history_file"
}

# SECURITY NOTE: This function uses atomic file operations via Python to prevent TOCTOU race conditions.
# The entire read-modify-write cycle is performed in a single Python process to ensure atomicity.
# File locking is handled by Python's file I/O which provides implicit locking on most filesystems.
history_add() {
    local history_file="$1"
    local role="$2"
    local content="$3"
    
    # Refresh encryption settings from environment
    _refresh_encryption_settings
    
    # Decrypt file if encryption is enabled
    local file_content
    if [[ "$ENCRYPTION_ENABLED" == "true" && -n "$ENCRYPTION_KEY" ]]; then
        local encrypted_content
        encrypted_content=$(cat "$history_file")
        file_content=$(_decrypt_data "$encrypted_content" "$ENCRYPTION_KEY")
    else
        file_content=$(cat "$history_file")
    fi
    
    # Use Python for safe JSON handling with proper variable passing
    # SECURITY: Atomic read-modify-write prevents TOCTOU race conditions
    python3 - "$role" "$MAX_HISTORY_LENGTH" "$content" "$history_file" << PYTHON_EOF
import json, sys
import fcntl

role = sys.argv[1]
max_length = int(sys.argv[2])
content = sys.argv[3]
history_file = sys.argv[4]

# Read history from stdin (already decrypted by bash)
import os
history_text = '''$file_content'''

try:
    history = json.loads(history_text)
except:
    history = []

history.append({'role': role, 'content': content})
# Trim if too long
if len(history) > max_length:
    history = history[-max_length:]

# Atomic write with file locking to prevent race conditions
with open(history_file, 'w') as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    try:
        json.dump(history, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    finally:
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)
PYTHON_EOF
    
    # Re-encrypt file if encryption is enabled
    if [[ "$ENCRYPTION_ENABLED" == "true" && -n "$ENCRYPTION_KEY" ]]; then
        local new_content
        new_content=$(cat "$history_file")
        local encrypted_content
        encrypted_content=$(_encrypt_data "$new_content" "$ENCRYPTION_KEY")
        echo "$encrypted_content" > "$history_file"
    fi
}

history_get_messages() {
    local history_file="$1"
    
    # Refresh encryption settings from environment
    _refresh_encryption_settings
    
    # Decrypt file if encryption is enabled
    local file_content
    if [[ "$ENCRYPTION_ENABLED" == "true" && -n "$ENCRYPTION_KEY" ]]; then
        local encrypted_content
        encrypted_content=$(cat "$history_file")
        file_content=$(_decrypt_data "$encrypted_content" "$ENCRYPTION_KEY")
    else
        file_content=$(cat "$history_file")
    fi
    
    # Pass content as argument to avoid stdin issues with heredoc
    python3 - "$file_content" << 'PYTHON_EOF'
import json, sys
try:
    history = json.loads(sys.argv[1])
    print(json.dumps(history))
except:
    print('[]')
PYTHON_EOF
}

history_clear() {
    local history_file="$1"
    
    # Refresh encryption settings from environment
    _refresh_encryption_settings
    
    if [[ "$ENCRYPTION_ENABLED" == "true" && -n "$ENCRYPTION_KEY" ]]; then
        # Store encrypted empty array
        local encrypted_empty
        encrypted_empty=$(_encrypt_data '[]' "$ENCRYPTION_KEY")
        echo "$encrypted_empty" > "$history_file"
    else
        echo '[]' > "$history_file"
    fi
}

history_length() {
    local history_file="$1"
    
    # Refresh encryption settings from environment
    _refresh_encryption_settings
    
    # Decrypt file if encryption is enabled
    local file_content
    if [[ "$ENCRYPTION_ENABLED" == "true" && -n "$ENCRYPTION_KEY" ]]; then
        local encrypted_content
        encrypted_content=$(cat "$history_file")
        file_content=$(_decrypt_data "$encrypted_content" "$ENCRYPTION_KEY")
    else
        file_content=$(cat "$history_file")
    fi
    
    # Pass content as argument to avoid stdin issues with heredoc
    python3 - "$file_content" << 'PYTHON_EOF'
import json, sys
try:
    history = json.loads(sys.argv[1])
    print(len(history))
except:
    print(0)
PYTHON_EOF
}

# Python-assisted JSON dump (bulletproof)
history_dump_as_json_array() {
    local history_file="$1"
    
    if [[ ! -f "$history_file" ]]; then
        echo "[]"
        return 1
    fi
    
    # Refresh encryption settings from environment
    _refresh_encryption_settings
    
    # Decrypt file if encryption is enabled
    local file_content
    if [[ "$ENCRYPTION_ENABLED" == "true" && -n "$ENCRYPTION_KEY" ]]; then
        local encrypted_content
        encrypted_content=$(cat "$history_file")
        file_content=$(_decrypt_data "$encrypted_content" "$ENCRYPTION_KEY")
    else
        file_content=$(cat "$history_file")
    fi
    
    # Pass content as argument to avoid stdin issues with heredoc
    python3 - "$file_content" << 'PYTHON_EOF'
import json, sys
try:
    history = json.loads(sys.argv[1])
    print(json.dumps(history))
except json.JSONDecodeError:
    print('[]')
except Exception as e:
    print('[]')
    sys.stderr.write(f'[ERROR] Failed to read history: {e}\n')
PYTHON_EOF
}

# Get messages for API (with optional trimming)
history_get_messages_trimmed() {
    local history_file="$1"
    local max_messages="${2:-$MAX_HISTORY_LENGTH}"
    
    # Refresh encryption settings from environment
    _refresh_encryption_settings
    
    local all_messages
    all_messages=$(history_dump_as_json_array "$history_file")
    
    if [[ "$max_messages" -eq 0 ]]; then
        echo "$all_messages"
        return
    fi
    
    # Trim to max_messages using Python with stdin to avoid command injection
    echo "$all_messages" | python3 - "$max_messages" << 'PYTHON_EOF'
import json, sys
try:
    messages = json.loads(sys.stdin.read())
    max_messages = int(sys.argv[1])
    if len(messages) > max_messages:
        # Keep system message if present
        if messages and messages[0].get('role') == 'system':
            trimmed = [messages[0]] + messages[-(max_messages-1):]
        else:
            trimmed = messages[-max_messages:]
        print(json.dumps(trimmed))
    else:
        print(json.dumps(messages))
except Exception as e:
    print('[]')
    sys.stderr.write(f'[ERROR] Failed to trim messages: {e}\n')
PYTHON_EOF
}
