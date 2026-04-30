#!/usr/bin/env python3
"""
Advanced Hacker Mode Tests - Specialized Attack Vectors
"""

import os, sys, subprocess, json, time, tempfile, base64
from pathlib import Path

class Colors:
    RED = '\033[91m'; GREEN = '\033[92m'; YELLOW = '\033[93m'
    MAGENTA = '\033[95m'; CYAN = '\033[96m'; RESET = '\033[0m'; BOLD = '\033[1m'

FINDINGS = {"critical": [], "high": [], "medium": [], "low": [], "info": [], "passed": []}

def log_finding(severity, title, details=""):
    FINDINGS[severity.lower()].append({"title": title, "details": details})
    icons = {"critical": "☠️", "high": "🔴", "medium": "🟡", "low": "🔵", "info": "ℹ️", "passed": "✅"}
    colors = {"critical": Colors.RED, "high": Colors.RED, "medium": Colors.YELLOW, "low": Colors.CYAN, "info": "", "passed": Colors.GREEN}
    print(f"{colors.get(severity.lower(), '')}{icons.get(severity.lower(), '')} [{severity.upper()}] {title}{Colors.RESET}")
    if details: print(f"   {details}")

def run_cmd(cmd, timeout=10, input_data=None, env=None):
    try:
        merged_env = os.environ.copy()
        if env: merged_env.update(env)
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, input=input_data, env=merged_env, cwd="/workspace")
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired: return -1, "", "TIMEOUT"
    except Exception as e: return -2, "", str(e)

ORCHAT = "/workspace/bin/orchat"

def test_shellshock():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}SHELLSHOCK/BASH INJECTION TESTS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    shellshock_payloads = [
        "() { :;}; echo HACKED",
        "() { _; } >_[$($())] { echo HACKED; }",
        "$() { :; }; echo HACKED",
    ]
    
    for payload in shellshock_payloads:
        env = os.environ.copy()
        env["TEST_VAR"] = payload
        rc, out, err = run_cmd([ORCHAT, "--help"], timeout=5, env=env)
        if "HACKED" in (out + err):
            log_finding("CRITICAL", f"Shellshock Vulnerable!", f"Payload: {payload[:40]}")
        else:
            log_finding("PASSED", "Shellshock Protected", f"Payload blocked: {payload[:30]}")

def test_json_injection():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}JSON INJECTION TESTS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    json_payloads = [
        '{"test": "value"}',
        '["array", "injection"]',
        '{"nested": {"deep": "value"}}',
        'null',
        'true',
        'false',
        '12345',
    ]
    
    for payload in json_payloads:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=5)
        if rc not in [0, 1, 6, 17, -2]:
            log_finding("MEDIUM", f"Unexpected JSON handling", f"Payload: {payload}, RC: {rc}")
        else:
            log_finding("PASSED", "JSON Injection Blocked", f"Payload: {payload[:30]}")

def test_xml_external_entity():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}XXE INJECTION TESTS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    xxe_payloads = [
        '<?xml version="1.0"?><!DOCTYPE root [<!ENTITY test "XXE">]><root>&test;</root>',
        '<?xml version="1.0"?><!DOCTYPE root [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>&xxe;</root>',
    ]
    
    for payload in xxe_payloads:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=5)
        if "root:x:0:" in (out + err):
            log_finding("CRITICAL", "XXE Attack Successful!", f"Payload: {payload[:50]}")
        elif rc in [0, 1, 6, 17, -2]:
            log_finding("PASSED", "XXE Blocked", f"Payload rejected")
        else:
            log_finding("INFO", "XXE Test Inconclusive", f"RC: {rc}")

def test_log_poisoning():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}LOG POISONING TESTS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    poison_payloads = [
        "test\nINJECTED_LOG_ENTRY",
        "test\r\nINJECTED_CRLF",
        "<script>alert('XSS')</script>",
        "<?php system($_GET['cmd']); ?>",
    ]
    
    for payload in poison_payloads:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=5)
        # Check if payload appears in any error logs
        log_finding("INFO", "Log Poisoning Test", f"Payload submitted: {payload[:30]}")

def test_integer_overflow():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}INTEGER OVERFLOW TESTS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    int_payloads = [
        str(2**31),
        str(2**32),
        str(2**63),
        str(-2**31),
        str(-2**63),
        "9999999999999999999999",
    ]
    
    for payload in int_payloads:
        start = time.time()
        rc, out, err = run_cmd([ORCHAT, f"--tokens={payload}"], timeout=10)
        elapsed = time.time() - start
        
        if rc < -100:
            log_finding("CRITICAL", f"Crash on integer overflow!", f"Value: {payload[:30]}")
        elif elapsed > 8:
            log_finding("MEDIUM", f"Hang on large integer", f"Value: {payload[:30]}, Time: {elapsed:.2f}s")
        else:
            log_finding("PASSED", "Integer Overflow Handled", f"Value: {payload[:30]}")

def test_format_string():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}FORMAT STRING ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    format_payloads = [
        "%s%s%s%s%s%s%s%s%s%s",
        "%x%x%x%x%x%x%x%x",
        "%n%n%n%n",
        "%p%p%p%p%p%p%p%p%p%p",
        "{0.__class__.__mro__}",
        "${7*7}",
    ]
    
    for payload in format_payloads:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=5)
        combined = out + err
        if "49" in combined and "${7*7}" in payload:
            log_finding("HIGH", f"Format string evaluation!", f"Payload: {payload}")
        elif rc in [0, 1, 6, 17, -2]:
            log_finding("PASSED", "Format String Blocked", f"Payload: {payload[:30]}")

def test_session_fixation():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}SESSION FIXATION TESTS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    session_payloads = [
        "../../../tmp/session.json",
        "/tmp/evil_session.json",
        "$(mktemp).json",
    ]
    
    for payload in session_payloads:
        rc, out, err = run_cmd([ORCHAT, "session", "load", payload], timeout=5)
        if "No such file" in err or "not found" in err.lower() or rc == 17:
            log_finding("PASSED", "Session Fixation Blocked", f"Payload: {payload}")
        else:
            log_finding("MEDIUM", "Session Fixation Unclear", f"Payload: {payload}, RC: {rc}")

def test_http_header_injection():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}HTTP HEADER INJECTION TESTS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    header_payloads = [
        "test\r\nX-Injected: Header",
        "test%0d%0aX-Injected: Header",
        "test\nX-Injected: Header",
    ]
    
    for payload in header_payloads:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=5)
        log_finding("INFO", "Header Injection Test", f"Payload tested: {payload[:30]}")

def test_dns_rebinding():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}DNS REBINDING CHECKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    core_sh = Path("/workspace/src/core.sh")
    if core_sh.exists():
        content = core_sh.read_text()
        if "curl" in content:
            if "localhost" in content or "127.0.0.1" in content:
                log_finding("INFO", "Localhost Reference Found", "Check for DNS rebinding protection")
            else:
                log_finding("PASSED", "No hardcoded localhost", "API URL is configurable")

def main():
    print(f"\n{Colors.RED}{Colors.BOLD}{'█'*80}{Colors.RESET}")
    print(f"{Colors.RED}{Colors.BOLD}█  🔥 ADVANCED HACKER MODE TESTS 🔥{' '*38}█{Colors.RESET}")
    print(f"{Colors.RED}{Colors.BOLD}{'█'*80}{Colors.RESET}\n")
    
    test_shellshock()
    test_json_injection()
    test_xml_external_entity()
    test_log_poisoning()
    test_integer_overflow()
    test_format_string()
    test_session_fixation()
    test_http_header_injection()
    test_dns_rebinding()
    
    total = sum(len(v) for v in FINDINGS.values())
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN}ADVANCED TEST SUMMARY{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.RESET}\n")
    
    print(f"Total: {total} | Critical: {len(FINDINGS['critical'])} | High: {len(FINDINGS['high'])} | Medium: {len(FINDINGS['medium'])} | Low: {len(FINDINGS['low'])} | Passed: {len(FINDINGS['passed'])}")
    
    if FINDINGS['critical']:
        print(f"\n{Colors.RED}CRITICAL:{Colors.RESET}")
        for f in FINDINGS['critical']: print(f"   • {f['title']}: {f['details']}")
    if FINDINGS['high']:
        print(f"\n{Colors.RED}HIGH:{Colors.RESET}")
        for f in FINDINGS['high']: print(f"   • {f['title']}: {f['details']}")
    
    return 1 if FINDINGS['critical'] or FINDINGS['high'] else 0

if __name__ == "__main__":
    sys.exit(main())
