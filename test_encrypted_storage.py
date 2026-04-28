#!/usr/bin/env python3
"""
Comprehensive Test Suite for Encrypted Local Storage Feature
Tests the encryption implementation in /workspace/src/history.sh
"""

import subprocess
import os
import sys
import json
import tempfile
import shutil

class TestEncryptedStorage:
    def __init__(self):
        self.test_dir = None
        self.passed = 0
        self.failed = 0
        self.results = []
        
    def setup(self):
        self.test_dir = tempfile.mkdtemp(prefix='orchat_encrypt_test_')
        print(f"[SETUP] Test directory: {self.test_dir}")
        
    def teardown(self):
        if self.test_dir and os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
        print(f"[TEARDOWN] Cleaned up test directory")
        
    def log_result(self, test_name, passed, details=""):
        status = "PASS" if passed else "FAIL"
        self.results.append((test_name, passed, details))
        if passed:
            self.passed += 1
        else:
            self.failed += 1
        print(f"{status}: {test_name}")
        if details:
            print(f"       {details}")
            
    def test_encryption_code_exists(self):
        history_sh_path = "/workspace/src/history.sh"
        
        if not os.path.exists(history_sh_path):
            self.log_result("Encryption code exists", False, "history.sh not found")
            return False
            
        with open(history_sh_path, 'r') as f:
            content = f.read()
            
        checks = [
            '_encrypt_data',
            '_decrypt_data', 
            'cryptography.fernet',
            'Fernet(',
            '.encrypt(',
            '.decrypt(',
            'ENCRYPTION_KEY',
            'ENCRYPTION_ENABLED',
        ]
        
        missing = []
        for pattern in checks:
            if pattern not in content:
                missing.append(pattern)
                
        if missing:
            self.log_result("Encryption code exists", False, f"Missing: {', '.join(missing)}")
            return False
        else:
            self.log_result("Encryption code exists", True, "All encryption components found")
            return True
            
    def test_encrypt_decrypt_roundtrip(self):
        test_content = '{"test": "hello world", "number": 42}'
        test_key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        
        script = f'''source /workspace/src/history.sh
export ORCHAT_ENCRYPTION_ENABLED=true
export ORCHAT_ENCRYPTION_KEY="{test_key}"
_refresh_encryption_settings
encrypted=$(_encrypt_data '{test_content}' "$ENCRYPTION_KEY")
echo "ENCRYPTED:$encrypted"
decrypted=$(_decrypt_data "$encrypted" "$ENCRYPTION_KEY")
echo "DECRYPTED:$decrypted"'''
        
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
        
        lines = result.stdout.split('\n')
        encrypted_line = [l for l in lines if l.startswith('ENCRYPTED:')][0]
        decrypted_line = [l for l in lines if l.startswith('DECRYPTED:')][0]
        
        encrypted = encrypted_line.replace('ENCRYPTED:', '')
        decrypted = decrypted_line.replace('DECRYPTED:', '')
        
        if decrypted == test_content:
            self.log_result("Encrypt/Decrypt roundtrip", True, f"Original: {test_content[:30]}...")
            return True
        else:
            self.log_result("Encrypt/Decrypt roundtrip", False, f"Expected: {test_content}, Got: {decrypted}")
            return False
            
    def test_encrypted_file_storage(self):
        test_key = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
        
        script = f'''export ORCHAT_HISTORY_DIR="{self.test_dir}"
export ORCHAT_ENCRYPTION_ENABLED=true
export ORCHAT_ENCRYPTION_KEY="{test_key}"
source /workspace/src/history.sh
hf=$(history_init "test_session")
echo "HISTORY_FILE:$hf"
history_add "$hf" "user" "Hello, this is a test message"
raw_content=$(cat "$hf")
echo "RAW_CONTENT:$raw_content"
messages=$(history_get_messages "$hf")
echo "MESSAGES:$messages"'''
        
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
        
        lines = result.stdout.split('\n')
        raw_content = [l for l in lines if l.startswith('RAW_CONTENT:')][0].replace('RAW_CONTENT:', '')
        messages = [l for l in lines if l.startswith('MESSAGES:')][0].replace('MESSAGES:', '')
        
        is_encrypted = not raw_content.strip().startswith('[')
        
        try:
            msg_data = json.loads(messages)
            has_correct_message = any('Hello, this is a test message' in str(m) for m in msg_data)
        except:
            has_correct_message = False
            
        if is_encrypted and has_correct_message:
            self.log_result("Encrypted file storage", True, "File stored encrypted, retrieved correctly")
            return True
        else:
            details = []
            if not is_encrypted:
                details.append("File not encrypted")
            if not has_correct_message:
                details.append("Message retrieval failed")
            self.log_result("Encrypted file storage", False, ', '.join(details))
            return False
            
    def test_key_generation(self):
        script = f'''export HOME="{self.test_dir}"
export ORCHAT_ENCRYPTION_ENABLED=true
unset ORCHAT_ENCRYPTION_KEY
source /workspace/src/history.sh
_init_encryption_key
echo "KEY_GENERATED:$ENCRYPTION_KEY"
echo "KEY_LENGTH:${{#ENCRYPTION_KEY}}"
if [[ -f "$HOME/.orchat/.encryption_key" ]]; then
    echo "KEY_FILE_EXISTS:true"
else
    echo "KEY_FILE_EXISTS:false"
fi'''
        
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
        
        lines = result.stdout.split('\n')
        key = [l for l in lines if l.startswith('KEY_GENERATED:')][0].replace('KEY_GENERATED:', '')
        key_length = [l for l in lines if l.startswith('KEY_LENGTH:')][0].replace('KEY_LENGTH:', '')
        key_file_exists = [l for l in lines if l.startswith('KEY_FILE_EXISTS:')][0].replace('KEY_FILE_EXISTS:', '')
        
        if key and int(key_length) >= 32 and key_file_exists == 'true':
            self.log_result("Key generation", True, f"Key length: {key_length}, file saved")
            return True
        else:
            self.log_result("Key generation", False, f"Key: {key[:10]}..., Length: {key_length}, File: {key_file_exists}")
            return False
            
    def test_disabled_encryption(self):
        script = f'''export ORCHAT_HISTORY_DIR="{self.test_dir}"
export ORCHAT_ENCRYPTION_ENABLED=false
unset ORCHAT_ENCRYPTION_KEY
source /workspace/src/history.sh
hf=$(history_init "disabled_session")
history_add "$hf" "user" "Unencrypted message"
cat "$hf"'''
        
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True)
        
        raw_content = result.stdout.strip()
        
        try:
            data = json.loads(raw_content)
            is_plain_json = isinstance(data, list)
        except:
            is_plain_json = False
            
        if is_plain_json:
            self.log_result("Disabled encryption", True, "Data stored as plain JSON")
            return True
        else:
            self.log_result("Disabled encryption", False, f"Data not stored as plain JSON. Content: {raw_content[:100]}")
            return False
            
    def run_all_tests(self):
        print("=" * 60)
        print("ENCRYPTED LOCAL STORAGE TEST SUITE")
        print("=" * 60)
        
        self.setup()
        
        try:
            self.test_encryption_code_exists()
            self.test_encrypt_decrypt_roundtrip()
            self.test_encrypted_file_storage()
            self.test_key_generation()
            self.test_disabled_encryption()
        finally:
            self.teardown()
            
        print("\n" + "=" * 60)
        print(f"RESULTS: {self.passed} passed, {self.failed} failed")
        print("=" * 60)
        
        return self.failed == 0

if __name__ == '__main__':
    tester = TestEncryptedStorage()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
