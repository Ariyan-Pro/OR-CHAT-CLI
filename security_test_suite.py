#!/usr/bin/env python3
"""
🔒 ORCHAT COMPREHENSIVE SECURITY & ROBUSTNESS TEST SUITE
Tests the project from every conceivable attack vector and edge case
"""

import os
import sys
import subprocess
import tempfile
import json
import shutil
import signal
from pathlib import Path
from typing import Tuple, Optional, List, Dict, Any

# Test results tracking
TEST_RESULTS = {
    "passed": [],
    "failed": [],
    "warnings": [],
    "critical": []
}

class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def log_test(name: str, status: str, details: str = ""):
    """Log test result with color coding"""
    if status == "PASS":
        TEST_RESULTS["passed"].append(name)
        print(f"{Colors.GREEN}✓ PASS{Colors.RESET}: {name}")
    elif status == "FAIL":
        TEST_RESULTS["failed"].append(name)
        print(f"{Colors.RED}✗ FAIL{Colors.RESET}: {name}")
    elif status == "WARN":
        TEST_RESULTS["warnings"].append(name)
        print(f"{Colors.YELLOW}⚠ WARN{Colors.RESET}: {name}")
    elif status == "CRITICAL":
        TEST_RESULTS["critical"].append(name)
        print(f"{Colors.RED}☠ CRITICAL{Colors.RESET}: {name}")
    
    if details:
        print(f"      {details}")

def run_command(cmd: List[str], timeout: int = 10, 
                input_data: Optional[str] = None,
                env: Optional[Dict] = None) -> Tuple[int, str, str]:
    """Run a command and return exit code, stdout, stderr"""
    try:
        merged_env = os.environ.copy()
        if env:
            merged_env.update(env)
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            input=input_data,
            env=merged_env
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "TIMEOUT"
    except Exception as e:
        return -2, "", str(e)

# ============================================================================
# SECTION 1: INPUT VALIDATION & INJECTION ATTACKS
# ============================================================================

def test_command_injection():
    """Test for command injection vulnerabilities"""
    print(f"\n{Colors.BOLD}=== COMMAND INJECTION TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    if not os.path.exists(orchat_path):
        log_test("Command Injection (basic)", "WARN", "orchat binary not found")
        return
    
    # Test 1: Basic command injection attempts
    payloads = [
        "test; ls -la",
        "test | cat /etc/passwd",
        "test && whoami",
        "test `whoami`",
        "test $(whoami)",
        "test || rm -rf /tmp/test_delete_me",
        "test; echo HACKED",
    ]
    
    for payload in payloads:
        rc, out, err = run_command([orchat_path, payload], timeout=5)
        # Should not execute injected commands
        if "HACKED" in out or "root" in out or "uid=" in out:
            log_test(f"Command Injection: {payload[:30]}", "CRITICAL", 
                    "Potential command injection detected!")
        else:
            log_test(f"Command Injection: {payload[:30]}", "PASS",
                    "Injection blocked")

def test_path_traversal():
    """Test for path traversal vulnerabilities"""
    print(f"\n{Colors.BOLD}=== PATH TRAVERSAL TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Test --system parameter with path traversal
    traversal_payloads = [
        "../../../etc/passwd",
        "../../../../etc/shadow",
        "/etc/passwd",
        "..\\..\\..\\etc\\passwd",
        "....//....//etc/passwd",
    ]
    
    for payload in traversal_payloads:
        rc, out, err = run_command(
            [orchat_path, "test", "--system", payload],
            timeout=5
        )
        if "root:" in out or "Permission denied" not in err:
            if "No such file" not in err and "not found" not in err.lower():
                log_test(f"Path Traversal: {payload}", "CRITICAL",
                        "Potential path traversal success!")
            else:
                log_test(f"Path Traversal: {payload}", "PASS",
                        "Traversal blocked by file system")
        else:
            log_test(f"Path Traversal: {payload}", "PASS",
                    "Access denied as expected")

def test_sql_injection():
    """Test for SQL injection (if any DB usage)"""
    print(f"\n{Colors.BOLD}=== SQL INJECTION TESTS ==={Colors.RESET}")
    
    # Check if any SQLite or database usage exists
    src_dir = Path("/workspace/src")
    db_files = list(src_dir.glob("*.sh"))
    
    sql_payloads = [
        "'; DROP TABLE users; --",
        "1 OR 1=1",
        "admin'--",
        "1; DELETE FROM sessions",
    ]
    
    found_db = False
    for script in db_files:
        content = script.read_text()
        if "sqlite" in content.lower() or "mysql" in content.lower():
            found_db = True
            break
    
    if not found_db:
        log_test("SQL Injection", "PASS", 
                "No database usage detected in shell scripts")
    else:
        log_test("SQL Injection", "WARN",
                "Database usage detected - manual review required")

def test_environment_variable_injection():
    """Test for environment variable manipulation"""
    print(f"\n{Colors.BOLD}=== ENVIRONMENT VARIABLE INJECTION ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Try to inject via environment variables
    malicious_env = {
        "ORCHAT_ROOT": "/tmp; echo HACKED;",
        "HOME": "/tmp/evil_home",
        "PATH": "/tmp:$PATH",
        "LD_PRELOAD": "/tmp/evil.so",
    }
    
    rc, out, err = run_command(
        [orchat_path, "--help"],
        timeout=5,
        env=malicious_env
    )
    
    if "HACKED" in out:
        log_test("Environment Variable Injection", "CRITICAL",
                "Environment variable injection successful!")
    else:
        log_test("Environment Variable Injection", "PASS",
                "Environment properly sanitized")

# ============================================================================
# SECTION 2: BUFFER OVERFLOWS & RESOURCE EXHAUSTION
# ============================================================================

def test_buffer_overflow():
    """Test for buffer overflow vulnerabilities"""
    print(f"\n{Colors.BOLD}=== BUFFER OVERFLOW TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Test with extremely long inputs
    test_cases = [
        ("A" * 10000, "10K characters"),
        ("A" * 100000, "100K characters"),
        ("A" * 1000000, "1M characters"),
    ]
    
    for payload, desc in test_cases:
        rc, out, err = run_command(
            [orchat_path, payload],
            timeout=10
        )
        
        if rc == -1:  # Timeout
            log_test(f"Buffer Overflow: {desc}", "WARN",
                    "Command timed out - possible DoS")
        elif rc < -100:  # Signal termination
            log_test(f"Buffer Overflow: {desc}", "CRITICAL",
                    f"Process crashed with signal {-rc-128}")
        else:
            log_test(f"Buffer Overflow: {desc}", "PASS",
                    f"Handled gracefully (exit code {rc})")

def test_resource_exhaustion():
    """Test for resource exhaustion attacks"""
    print(f"\n{Colors.BOLD}=== RESOURCE EXHAUSTION TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Rapid fire requests
    log_test("Resource Exhaustion: Rapid Requests", "WARN",
            "Testing 100 rapid requests...")
    
    start_time = __import__('time').time()
    failures = 0
    for i in range(100):
        rc, _, _ = run_command(
            [orchat_path, f"test {i}"],
            timeout=2
        )
        if rc == -1:
            failures += 1
    
    elapsed = __import__('time').time() - start_time
    
    if failures > 50:
        log_test("Resource Exhaustion: Rate Limiting", "WARN",
                f"{failures}/100 requests timed out")
    else:
        log_test("Resource Exhaustion: Rate Limiting", "PASS",
                f"Completed in {elapsed:.2f}s ({failures} timeouts)")

def test_fork_bomb_protection():
    """Test protection against fork bombs"""
    print(f"\n{Colors.BOLD}=== FORK BOMB PROTECTION ==={Colors.RESET}")
    
    # Check if there are any eval/exec without limits
    src_files = Path("/workspace/src").glob("*.sh")
    
    dangerous_patterns = ["eval ", "exec ", "$(", "`"]
    
    for src_file in src_files:
        content = src_file.read_text()
        for pattern in dangerous_patterns:
            if pattern in content:
                count = content.count(pattern)
                if count > 5:
                    log_test(f"Fork Bomb Protection: {src_file.name}", "WARN",
                            f"Found {count} instances of '{pattern}'")
                    break
        else:
            continue
        break
    else:
        log_test("Fork Bomb Protection", "PASS",
                "No excessive use of dangerous constructs")

# ============================================================================
# SECTION 3: CONFIGURATION & SECRETS MANAGEMENT
# ============================================================================

def test_secrets_exposure():
    """Test for secrets exposure vulnerabilities"""
    print(f"\n{Colors.BOLD}=== SECRETS EXPOSURE TESTS ==={Colors.RESET}")
    
    # Check config files for hardcoded secrets
    config_files = [
        "/workspace/config/orchat.toml",
        "/workspace/.env",
        "/workspace/src/constants.sh",
    ]
    
    secret_patterns = [
        "sk-or-",
        "api_key",
        "password",
        "secret",
        "token",
    ]
    
    for config_file in config_files:
        if os.path.exists(config_file):
            content = Path(config_file).read_text()
            for pattern in secret_patterns:
                if pattern.lower() in content.lower():
                    # Check if it's actually a secret or just a variable name
                    if "=" in content and pattern in content:
                        lines = content.split('\n')
                        for line in lines:
                            if pattern.lower() in line.lower() and '=' in line:
                                if 'YOUR_' not in line.upper() and 'EXAMPLE' not in line.upper():
                                    log_test(f"Secrets Exposure: {config_file}", "CRITICAL",
                                            f"Potential hardcoded secret: {line[:50]}")
                                    break
                        else:
                            continue
                        break
            else:
                log_test(f"Secrets Exposure: {os.path.basename(config_file)}", "PASS",
                        "No obvious secrets found")
        else:
            log_test(f"Secrets Exposure: {os.path.basename(config_file)}", "PASS",
                    "File does not exist")

def test_config_injection():
    """Test for configuration injection"""
    print(f"\n{Colors.BOLD}=== CONFIGURATION INJECTION TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Try to inject config values via command line
    config_payloads = [
        ("config", "set", "api_key", "injected_value"),
        ("config", "set", "../etc/passwd", "value"),
        ("config", "set", "$(whoami)", "value"),
        ("config", "set", "`id`", "value"),
    ]
    
    for payload in config_payloads:
        rc, out, err = run_command(
            [orchat_path] + list(payload),
            timeout=5
        )
        
        if "injected_value" in out or "root" in out:
            log_test(f"Config Injection: {payload[2]}", "CRITICAL",
                    "Configuration injection successful!")
        elif rc != 0 and ("error" in err.lower() or "invalid" in err.lower()):
            log_test(f"Config Injection: {payload[2]}", "PASS",
                    "Injection blocked with error")
        else:
            log_test(f"Config Injection: {payload[2]}", "WARN",
                    f"Exit code: {rc}, needs review")

# ============================================================================
# SECTION 4: FILE SYSTEM ATTACKS
# ============================================================================

def test_symlink_attack():
    """Test for symlink-based attacks"""
    print(f"\n{Colors.BOLD}=== SYMLINK ATTACK TESTS ==={Colors.RESET}")
    
    # Create a temporary directory for testing
    test_dir = tempfile.mkdtemp(prefix="orchat_test_")
    
    try:
        # Create a symlink to /etc/passwd
        symlink_path = os.path.join(test_dir, "passwd_link")
        os.symlink("/etc/passwd", symlink_path)
        
        orchat_path = "/workspace/bin/orchat"
        
        # Try to use the symlink with --system
        rc, out, err = run_command(
            [orchat_path, "test", "--system", symlink_path],
            timeout=5
        )
        
        if "root:" in out:
            log_test("Symlink Attack", "CRITICAL",
                    "Symlink traversal successful!")
        else:
            log_test("Symlink Attack", "PASS",
                    "Symlink access blocked")
    
    finally:
        shutil.rmtree(test_dir, ignore_errors=True)

def test_race_condition():
    """Test for TOCTOU race conditions"""
    print(f"\n{Colors.BOLD}=== RACE CONDITION TESTS ==={Colors.RESET}")
    
    # Check for common TOCTOU patterns in code
    src_files = list(Path("/workspace/src").glob("*.sh"))
    
    toctou_patterns = [
        ("-f", "then"),  # File existence check followed by action
        ("test -f", "cat"),
        ("[[ -f", "source"),
    ]
    
    found_issues = []
    for src_file in src_files:
        content = src_file.read_text()
        lines = content.split('\n')
        
        for i, line in enumerate(lines):
            for check_pattern, action_pattern in toctou_patterns:
                if check_pattern in line:
                    # Check next few lines for the action
                    for j in range(i+1, min(i+5, len(lines))):
                        if action_pattern in lines[j]:
                            found_issues.append(f"{src_file.name}:{i+1}")
    
    if found_issues:
        log_test("Race Condition (TOCTOU)", "WARN",
                f"Potential issues in: {', '.join(found_issues[:5])}")
    else:
        log_test("Race Condition (TOCTOU)", "PASS",
                "No obvious TOCTOU patterns found")

def test_temp_file_security():
    """Test for insecure temporary file usage"""
    print(f"\n{Colors.BOLD}=== TEMPORARY FILE SECURITY ==={Colors.RESET}")
    
    src_files = list(Path("/workspace/src").glob("*.sh"))
    
    insecure_patterns = [
        "/tmp/orchat_",  # Predictable temp file names
        "/tmp/test",     # Generic temp names
        "mktemp -t",     # Without proper template
    ]
    
    secure_patterns = [
        "mktemp",        # Secure temp file creation
        "TMPDIR=",       # Custom temp directory
    ]
    
    for src_file in src_files:
        content = src_file.read_text()
        
        has_insecure = any(p in content for p in insecure_patterns)
        has_secure = any(p in content for p in secure_patterns)
        
        if has_insecure and not has_secure:
            log_test(f"Temp File Security: {src_file.name}", "WARN",
                    "Uses potentially insecure temp file patterns")
        elif has_secure:
            log_test(f"Temp File Security: {src_file.name}", "PASS",
                    "Uses secure temp file creation")
        else:
            log_test(f"Temp File Security: {src_file.name}", "PASS",
                    "No temp file usage detected")

# ============================================================================
# SECTION 5: DENIAL OF SERVICE ATTACKS
# ============================================================================

def test_null_byte_injection():
    """Test for null byte injection"""
    print(f"\n{Colors.BOLD}=== NULL BYTE INJECTION TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Null byte payloads
    payloads = [
        "test\x00injection",
        "file.txt\x00.exe",
        "../etc/passwd\x00",
    ]
    
    for payload in payloads:
        rc, out, err = run_command(
            [orchat_path, payload],
            timeout=5
        )
        
        # Check if null byte caused unexpected behavior
        if rc == -2 or "null" in err.lower():
            log_test(f"Null Byte: {repr(payload[:20])}", "WARN",
                    "Null byte caused error")
        else:
            log_test(f"Null Byte: {repr(payload[:20])}", "PASS",
                    "Handled gracefully")

def test_unicode_attacks():
    """Test for unicode-based attacks"""
    print(f"\n{Colors.BOLD}=== UNICODE ATTACK TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Unicode payloads
    payloads = [
        "test\u202Egnirts",  # Right-to-left override
        "test\u200B",  # Zero-width space
        "test\udcff",  # Invalid UTF-8
        "test𐍈𐍉𐍄𐌰",  # Gothic script
    ]
    
    for payload in payloads:
        rc, out, err = run_command(
            [orchat_path, payload],
            timeout=5
        )
        
        if rc == -2 or "unicode" in err.lower() or "utf" in err.lower():
            log_test(f"Unicode Attack: {repr(payload[:20])}", "WARN",
                    "Unicode caused processing error")
        else:
            log_test(f"Unicode Attack: {repr(payload[:20])}", "PASS",
                    "Unicode handled correctly")

def test_recursive_input():
    """Test for recursive/self-referential input"""
    print(f"\n{Colors.BOLD}=== RECURSIVE INPUT TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Self-referential payloads
    payloads = [
        "Repeat this: " + "Repeat this: " * 100,
        '{"recursive": ' * 100 + '}',
        "[" * 500 + "]" * 500,
    ]
    
    for payload in payloads:
        start_time = __import__('time').time()
        rc, out, err = run_command(
            [orchat_path, payload],
            timeout=10
        )
        elapsed = __import__('time').time() - start_time
        
        if elapsed > 5:
            log_test(f"Recursive Input: {len(payload)} chars", "WARN",
                    f"Took {elapsed:.2f}s - potential ReDoS")
        elif rc == -1:
            log_test(f"Recursive Input: {len(payload)} chars", "CRITICAL",
                    "Timeout - possible infinite loop")
        else:
            log_test(f"Recursive Input: {len(payload)} chars", "PASS",
                    f"Processed in {elapsed:.2f}s")

# ============================================================================
# SECTION 6: API & NETWORK SECURITY
# ============================================================================

def test_api_key_handling():
    """Test API key security"""
    print(f"\n{Colors.BOLD}=== API KEY HANDLING TESTS ==={Colors.RESET}")
    
    # Check if API keys are logged
    log_files = [
        "/workspace/logs/orchat.log",
        "/var/log/orchat.log",
    ]
    
    for log_file in log_files:
        if os.path.exists(log_file):
            content = Path(log_file).read_text()
            if "sk-or-" in content or "api_key" in content.lower():
                log_test(f"API Key Logging: {log_file}", "CRITICAL",
                        "API keys may be logged!")
            else:
                log_test(f"API Key Logging: {log_file}", "PASS",
                        "No API keys in logs")
    
    # Check environment variable exposure
    rc, out, err = run_command(
        ["bash", "-c", "env | grep -i api"],
        timeout=5
    )
    
    if "sk-or-" in out:
        log_test("API Key in Environment", "CRITICAL",
                "API key exposed in environment variables!")
    else:
        log_test("API Key in Environment", "PASS",
                "API key not in environment")

def test_ssrf_vulnerability():
    """Test for Server-Side Request Forgery"""
    print(f"\n{Colors.BOLD}=== SSRF VULNERABILITY TESTS ==={Colors.RESET}")
    
    # Check if there's any URL fetching capability
    src_files = list(Path("/workspace/src").glob("*.sh"))
    
    ssrf_patterns = [
        "curl http",
        "wget http",
        "fetch http",
    ]
    
    found_ssrf = False
    for src_file in src_files:
        content = src_file.read_text()
        for pattern in ssrf_patterns:
            if pattern in content:
                found_ssrf = True
                break
    
    if found_ssrf:
        log_test("SSRF Vulnerability", "WARN",
                "HTTP client functionality detected - review URL validation")
    else:
        log_test("SSRF Vulnerability", "PASS",
                "No direct HTTP client usage found")

# ============================================================================
# SECTION 7: ERROR HANDLING & INFORMATION LEAKAGE
# ============================================================================

def test_error_message_leakage():
    """Test for sensitive information in error messages"""
    print(f"\n{Colors.BOLD}=== ERROR MESSAGE LEAKAGE TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Trigger various errors
    error_triggers = [
        ["--nonexistent-option"],
        ["config", "get", "nonexistent_key_xyz123"],
        ["session", "load", "/nonexistent/file.json"],
        ["--system", "/nonexistent/file.txt"],
    ]
    
    sensitive_patterns = [
        "Traceback",
        "stack trace",
        "/home/",
        "/root/",
        "password",
        "api_key",
        "secret",
    ]
    
    for trigger in error_triggers:
        rc, out, err = run_command(
            [orchat_path] + trigger,
            timeout=5
        )
        
        output = out + err
        for pattern in sensitive_patterns:
            if pattern.lower() in output.lower():
                log_test(f"Error Leakage: {' '.join(trigger)}", "WARN",
                        f"Sensitive info in error: {pattern}")
                break
        else:
            log_test(f"Error Leakage: {' '.join(trigger)}", "PASS",
                    "Error message is safe")

def test_stack_trace_exposure():
    """Test for stack trace exposure"""
    print(f"\n{Colors.BOLD}=== STACK TRACE EXPOSURE TESTS ==={Colors.RESET}")
    
    orchat_path = "/workspace/bin/orchat"
    
    # Force crashes
    crash_inputs = [
        "${BASH_SOURCE[0]}",
        "$(( 1 / 0 ))",
        "$(exit 1)",
    ]
    
    for crash_input in crash_inputs:
        rc, out, err = run_command(
            [orchat_path, crash_input],
            timeout=5
        )
        
        output = out + err
        if "Traceback" in output or "stack trace" in output.lower():
            log_test(f"Stack Trace: {crash_input[:20]}", "CRITICAL",
                    "Stack trace exposed!")
        else:
            log_test(f"Stack Trace: {crash_input[:20]}", "PASS",
                    "No stack trace exposure")

# ============================================================================
# SECTION 8: SHELL-SPECIFIC VULNERABILITIES
# ============================================================================

def test_shell_injection_in_scripts():
    """Test for shell injection in script files"""
    print(f"\n{Colors.BOLD}=== SHELL INJECTION IN SCRIPTS ==={Colors.RESET}")
    
    src_files = list(Path("/workspace/src").glob("*.sh"))
    
    dangerous_constructs = [
        ("eval $", "Unquoted eval"),
        ("$USER", "Unsanitized USER variable"),
        ("$HOME", "Unsanitized HOME variable"),
        ("$(cat ", "Command substitution with cat"),
        ("`cat ", "Backtick command substitution"),
    ]
    
    for src_file in src_files:
        content = src_file.read_text()
        
        for pattern, description in dangerous_constructs:
            if pattern in content:
                # Check if it's properly quoted/sanitized
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if pattern in line:
                        # Simple heuristic: check for quotes nearby
                        if '"' not in line and "'" not in line:
                            log_test(f"Shell Injection: {src_file.name}:{i+1}", "WARN",
                                    f"Potentially unsafe: {description}")
    
    log_test("Shell Injection: Overall", "PASS",
            "Basic scan complete - manual review recommended")

def test_unsafe_expansion():
    """Test for unsafe glob expansion"""
    print(f"\n{Colors.BOLD}=== UNSAFE GLOB EXPANSION ==={Colors.RESET}")
    
    src_files = list(Path("/workspace/src").glob("*.sh"))
    
    unsafe_patterns = [
        "for f in *",
        "for f in $",
        "ls $",
        "echo $*",
        "echo $@",
    ]
    
    for src_file in src_files:
        content = src_file.read_text()
        
        for pattern in unsafe_patterns:
            if pattern in content:
                log_test(f"Unsafe Glob: {src_file.name}", "WARN",
                        f"Found pattern: {pattern}")
                break
        else:
            continue
        break
    else:
        log_test("Unsafe Glob Expansion", "PASS",
                "No obvious unsafe glob patterns")

# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    """Run all security tests"""
    print(f"{Colors.BOLD}{Colors.CYAN}")
    print("=" * 80)
    print("🔒 ORCHAT COMPREHENSIVE SECURITY TEST SUITE")
    print("=" * 80)
    print(f"{Colors.RESET}")
    
    # Run all test sections
    test_command_injection()
    test_path_traversal()
    test_sql_injection()
    test_environment_variable_injection()
    
    test_buffer_overflow()
    test_resource_exhaustion()
    test_fork_bomb_protection()
    
    test_secrets_exposure()
    test_config_injection()
    
    test_symlink_attack()
    test_race_condition()
    test_temp_file_security()
    
    test_null_byte_injection()
    test_unicode_attacks()
    test_recursive_input()
    
    test_api_key_handling()
    test_ssrf_vulnerability()
    
    test_error_message_leakage()
    test_stack_trace_exposure()
    
    test_shell_injection_in_scripts()
    test_unsafe_expansion()
    
    # Print summary
    print(f"\n{Colors.BOLD}{Colors.CYAN}")
    print("=" * 80)
    print("📊 TEST SUMMARY")
    print("=" * 80)
    print(f"{Colors.RESET}")
    
    total = (len(TEST_RESULTS["passed"]) + len(TEST_RESULTS["failed"]) + 
             len(TEST_RESULTS["warnings"]) + len(TEST_RESULTS["critical"]))
    
    print(f"Total Tests: {total}")
    print(f"{Colors.GREEN}Passed: {len(TEST_RESULTS['passed'])}{Colors.RESET}")
    print(f"{Colors.RED}Failed: {len(TEST_RESULTS['failed'])}{Colors.RESET}")
    print(f"{Colors.YELLOW}Warnings: {len(TEST_RESULTS['warnings'])}{Colors.RESET}")
    print(f"{Colors.RED}Critical: {len(TEST_RESULTS['critical'])}{Colors.RESET}")
    
    if TEST_RESULTS["critical"]:
        print(f"\n{Colors.RED}{Colors.BOLD}⚠️  CRITICAL ISSUES FOUND:{Colors.RESET}")
        for issue in TEST_RESULTS["critical"]:
            print(f"   • {issue}")
    
    if TEST_RESULTS["warnings"]:
        print(f"\n{Colors.YELLOW}⚠️  WARNINGS:{Colors.RESET}")
        for warning in TEST_RESULTS["warnings"][:10]:
            print(f"   • {warning}")
        if len(TEST_RESULTS["warnings"]) > 10:
            print(f"   ... and {len(TEST_RESULTS['warnings']) - 10} more")
    
    # Determine overall status
    if TEST_RESULTS["critical"]:
        print(f"\n{Colors.RED}{Colors.BOLD}❌ SECURITY STATUS: CRITICAL - IMMEDIATE ACTION REQUIRED{Colors.RESET}")
        return 1
    elif TEST_RESULTS["failed"]:
        print(f"\n{Colors.YELLOW}{Colors.BOLD}⚠️  SECURITY STATUS: NEEDS IMPROVEMENT{Colors.RESET}")
        return 1
    elif TEST_RESULTS["warnings"]:
        print(f"\n{Colors.YELLOW}{Colors.BOLD}⚠️  SECURITY STATUS: ACCEPTABLE WITH WARNINGS{Colors.RESET}")
        return 0
    else:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✅ SECURITY STATUS: PASSED ALL TESTS{Colors.RESET}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
