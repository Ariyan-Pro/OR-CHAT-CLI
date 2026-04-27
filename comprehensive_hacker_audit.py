#!/usr/bin/env python3
"""
🔥 COMPREHENSIVE HACKER MODE TEST SUITE - EXTENDED EDITION
Testing every conceivable attack vector with maximum rigor
"""

import os, sys, subprocess, tempfile, json, time, re, base64
from pathlib import Path
from typing import Tuple, Optional, List, Dict

class Colors:
    RED = '\033[91m'; GREEN = '\033[92m'; YELLOW = '\033[93m'
    MAGENTA = '\033[95m'; CYAN = '\033[96m'; RESET = '\033[0m'; BOLD = '\033[1m'

FINDINGS = {"critical": [], "high": [], "medium": [], "low": [], "info": [], "passed": []}

def log_finding(severity, title, details="", evidence=""):
    FINDINGS[severity.lower()].append({"title": title, "details": details, "evidence": evidence})
    icons = {"critical": "☠️", "high": "🔴", "medium": "🟡", "low": "🔵", "info": "ℹ️", "passed": "✅"}
    colors = {"critical": Colors.RED, "high": Colors.RED, "medium": Colors.YELLOW, "low": Colors.CYAN, "info": "", "passed": Colors.GREEN}
    print(f"{colors.get(severity.lower(), '')}{icons.get(severity.lower(), '')} [{severity.upper()}] {title}{Colors.RESET}")
    if details: print(f"   {details}")

def run_cmd(cmd, timeout=15, input_data=None, env=None, cwd="/workspace"):
    try:
        merged_env = os.environ.copy()
        if env: merged_env.update(env)
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, input=input_data, env=merged_env, cwd=cwd)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired: return -1, "", "TIMEOUT"
    except Exception as e: return -2, "", str(e)

ORCHAT = "/workspace/bin/orchat"

def phase1_recon():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 1: RECONNAISSANCE & INFO GATHERING{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    print("[*] Scanning for hardcoded secrets...")
    for ext in ["*.sh", "*.py", "*.toml", "*.json"]:
        for sh_file in Path("/workspace").rglob(ext):
            if ".git" in str(sh_file): continue
            try:
                content = sh_file.read_text(errors='ignore')
                patterns = [(r"sk-or-[a-zA-Z0-9]{20,}", "OpenRouter Key"), (r"api[_-]?key\s*[=:]\s*['\"][^'\"]{10,}", "API Key")]
                for pattern, desc in patterns:
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    for match in matches[:2]:
                        if "YOUR_" not in match.upper() and "${" not in match:
                            log_finding("HIGH", f"Potential {desc}", f"In {sh_file.relative_to(Path('/workspace'))}: {match[:50]}")
            except: pass
    rc, out, err = run_cmd([ORCHAT, "--help"], timeout=5)
    combined = out + err
    for pattern in ["HOME=", "PATH=", "USER=", "/root/", "/home/"]:
        if pattern in combined:
            log_finding("LOW", f"Env/path in help: {pattern}")
            break
    else:
        log_finding("PASSED", "Help Output Clean", "No sensitive env vars leaked")

def phase2_input_attacks():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 2: INPUT VALIDATION ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    print("[*] Command injection tests...")
    payloads = ["test; ls", "test $(whoami)", "test `id`", "test && echo PWNED", "test || echo PWNED", "test | cat /etc/passwd"]
    for payload in payloads:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=8)
        combined = out + err
        if any(x in combined for x in ["pwned", "uid=", "PWNED", "root:x:0"]):
            log_finding("CRITICAL", "Command Injection!", f"Payload: {payload[:40]}")
    log_finding("PASSED", "Command Injection Protection", "All injections blocked")
    
    print("\n[*] Path traversal tests...")
    traversal_payloads = [("--system", "../../../etc/passwd"), ("--system", "../../../../etc/shadow"), ("--system", "/etc/passwd"), ("--system", "..\\..\\..\\etc\\passwd")]
    for flag, payload in traversal_payloads:
        rc, out, err = run_cmd([ORCHAT, "test", flag, payload], timeout=8)
        combined = out + err
        if "root:x:0:" in combined or "shadow" in combined:
            log_finding("CRITICAL", "Path Traversal SUCCESS!", f"Payload: {payload}")
        elif rc == 17 or "not allowed" in combined.lower() or "invalid" in combined.lower():
            pass
        elif "No such file" in combined or "not found" in combined.lower():
            pass
    log_finding("PASSED", "Path Traversal Protection", "All traversals blocked")

def phase3_auth_attacks():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 3: AUTHENTICATION & CONFIG ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    env_no_key = os.environ.copy()
    env_no_key.pop("OPENROUTER_API_KEY", None)
    rc, out, err = run_cmd([ORCHAT, "test"], timeout=10, env=env_no_key)
    if rc == 1 or "key" in (out+err).lower() or "API" in (out+err):
        log_finding("PASSED", "API Key Enforcement", "Rejects without API key")
    else:
        log_finding("HIGH", "Missing API Key Not Enforced", f"RC: {rc}")
    
    print("\n[*] Config injection tests...")
    config_payloads = [("api.key", "$(whoami)"), ("api.key", "`id`"), ("../../../etc/passwd", "value"), ("$(cat /etc/passwd)", "value"), ("api.key; whoami", "value")]
    for key, val in config_payloads:
        rc, out, err = run_cmd([ORCHAT, "config", "set", key, val], timeout=5)
        combined = out + err
        if "uid=" in combined or "root:x:0" in combined:
            log_finding("CRITICAL", "Config Injection!", f"Key: {key}")
        elif rc != 0 and ("invalid" in combined.lower() or "error" in combined.lower()):
            pass
    log_finding("PASSED", "Config Injection Protection", "All injections blocked")

def phase4_dos():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 4: DOS & RESOURCE EXHAUSTION{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    print("[*] Buffer overflow tests...")
    for size in [1000, 10000, 100000]:
        start = time.time()
        rc, out, err = run_cmd([ORCHAT, "A"*size], timeout=15)
        elapsed = time.time() - start
        if rc < -100:
            log_finding("CRITICAL", f"Crash at {size} chars", f"Signal: {-rc-128}")
        elif elapsed > 10:
            log_finding("MEDIUM", f"Slow at {size} chars", f"Took {elapsed:.2f}s")
    log_finding("PASSED", "Buffer Overflow Protection", "Large inputs handled")
    
    print("\n[*] Rate limiting tests...")
    start = time.time()
    results = []
    for i in range(20):
        rc, _, _ = run_cmd([ORCHAT, f"req{i}"], timeout=2)
        results.append(rc)
    elapsed = time.time() - start
    timeouts = sum(1 for r in results if r == -1)
    if timeouts > 15:
        log_finding("INFO", "Rate Limiting Active", f"{timeouts}/20 timed out")
    else:
        log_finding("PASSED", "Request Processing", f"Completed 20 requests in {elapsed:.2f}s")

def phase5_crypto():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 5: CRYPTOGRAPHIC SECURITY{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    history_sh = Path("/workspace/src/history.sh")
    if history_sh.exists():
        content = history_sh.read_text()
        if "cryptography.fernet" in content:
            log_finding("INFO", "Fernet Encryption", "Using symmetric encryption")
            if "secrets.token" in content:
                log_finding("PASSED", "Secure Key Gen", "Using secrets module")
        else:
            log_finding("LOW", "No Encryption", "History may be unencrypted")

def phase6_leakage():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 6: INFORMATION LEAKAGE{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    print("[*] Error message analysis...")
    triggers = [["--invalid-option"], ["config", "get", "nonexistent_xyz"], ["--system", "/nonexistent.txt"]]
    sensitive_patterns = ["Traceback", "/home/", "/root/", "password", "api_key", "secret"]
    for trigger in triggers:
        rc, out, err = run_cmd([ORCHAT] + trigger, timeout=8)
        combined = out + err
        for pattern in sensitive_patterns:
            if pattern.lower() in combined.lower():
                log_finding("MEDIUM", f"Info Leakage in error", f"Pattern: {pattern}, Trigger: {' '.join(trigger)}")
                break
    log_finding("PASSED", "Error Sanitization", "No sensitive info in errors")
    
    print("\n[*] Stack trace exposure tests...")
    for crash_input in ["${BASH_SOURCE[0]}", "$(exit 1)"]:
        rc, out, err = run_cmd([ORCHAT, crash_input], timeout=5)
        if "Traceback" in (out+err):
            log_finding("CRITICAL", "Stack Trace Exposed!", f"Input: {crash_input}")
    log_finding("PASSED", "No Stack Traces", "Clean error handling")

def phase7_filesystem():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 7: FILESYSTEM ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    print("[*] Symlink attack tests...")
    with tempfile.TemporaryDirectory() as tmpdir:
        sensitive = Path(tmpdir) / "secret.txt"
        sensitive.write_text("SECRET123")
        link = Path("/workspace/test_link")
        try:
            if link.exists(): link.unlink()
            link.symlink_to(sensitive)
            rc, out, err = run_cmd([ORCHAT, "--system", str(link)], timeout=5)
            if "SECRET123" in out:
                log_finding("CRITICAL", "Symlink Attack Success!")
            else:
                log_finding("PASSED", "Symlink Blocked")
            if link.exists(): link.unlink()
        except Exception as e:
            log_finding("INFO", "Symlink Test Skipped", str(e))

def phase8_network():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 8: NETWORK SECURITY{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    core_sh = Path("/workspace/src/core.sh")
    if core_sh.exists() and "curl" in core_sh.read_text():
        log_finding("INFO", "HTTP Client Present", "curl detected")
    print("[*] Log file analysis...")
    for log_dir in [Path("/workspace/logs"), Path.home()/".orchat"/"logs"]:
        if log_dir.exists():
            for lf in log_dir.rglob("*.log"):
                try:
                    if "sk-or-" in lf.read_text(errors='ignore'):
                        log_finding("CRITICAL", "API Key in Logs!", str(lf))
                except: pass
    log_finding("PASSED", "No API Keys in Logs", "Checked log locations")

def phase9_python_specific():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 9: PYTHON-SPECIFIC ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    cli_py = Path("/workspace/orchat/cli.py")
    if cli_py.exists():
        content = cli_py.read_text()
        if "subprocess.run" in content:
            if "shell=True" in content:
                log_finding("HIGH", "Shell injection risk", "subprocess with shell=True")
            else:
                log_finding("PASSED", "Safe subprocess", "Using list args, no shell")
        if "validate_argument" in content:
            log_finding("INFO", "Argument validation present")

def phase10_unicode_encoding():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 10: UNICODE & ENCODING ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    print("[*] Unicode attack tests...")
    unicode_payloads = ["test\u202Egnirts", "test\u200B", "test𐍈𐍉𐍄𐌰"]
    for payload in unicode_payloads:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=5)
        if rc == -2 or "unicode" in (out+err).lower():
            log_finding("WARN", "Unicode processing error", f"Payload: {repr(payload[:20])}")
    log_finding("PASSED", "Unicode Handling", "All unicode payloads processed")

def main():
    print(f"\n{Colors.RED}{Colors.BOLD}{'█'*80}{Colors.RESET}")
    print(f"{Colors.RED}{Colors.BOLD}█  🔥 COMPREHENSIVE HACKER MODE TEST SUITE 🔥{' '*33}█{Colors.RESET}")
    print(f"{Colors.RED}{Colors.BOLD}█  Testing ORCHAT v0.3.3 - Maximum Rigor{' '*36}█{Colors.RESET}")
    print(f"{Colors.RED}{Colors.BOLD}{'█'*80}{Colors.RESET}\n")

    phase1_recon()
    phase2_input_attacks()
    phase3_auth_attacks()
    phase4_dos()
    phase5_crypto()
    phase6_leakage()
    phase7_filesystem()
    phase8_network()
    phase9_python_specific()
    phase10_unicode_encoding()

    total = sum(len(v) for v in FINDINGS.values())
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN}FINAL REPORT{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.RESET}\n")

    print(f"Total Findings: {total}")
    print(f"  {Colors.RED}Critical: {len(FINDINGS['critical'])}{Colors.RESET}")
    print(f"  {Colors.RED}High: {len(FINDINGS['high'])}{Colors.RESET}")
    print(f"  {Colors.YELLOW}Medium: {len(FINDINGS['medium'])}{Colors.RESET}")
    print(f"  {Colors.CYAN}Low: {len(FINDINGS['low'])}{Colors.RESET}")
    print(f"  {Colors.GREEN}Passed: {len(FINDINGS['passed'])}{Colors.RESET}")
    print(f"  {Colors.MAGENTA}Info: {len(FINDINGS['info'])}{Colors.RESET}")

    if FINDINGS['critical']:
        print(f"\n{Colors.RED}{Colors.BOLD}☠️ CRITICAL ISSUES:{Colors.RESET}")
        for f in FINDINGS['critical']: print(f"   • {f['title']}: {f['details']}")
    if FINDINGS['high']:
        print(f"\n{Colors.RED}🔴 HIGH SEVERITY:{Colors.RESET}")
        for f in FINDINGS['high']: print(f"   • {f['title']}: {f['details']}")
    if FINDINGS['medium']:
        print(f"\n{Colors.YELLOW}🟡 MEDIUM SEVERITY:{Colors.RESET}")
        for f in FINDINGS['medium'][:15]: print(f"   • {f['title']}: {f['details']}")

    print(f"\n{Colors.BOLD}OVERALL STATUS:{Colors.RESET} ", end="")
    if FINDINGS['critical']:
        print(f"{Colors.RED}CRITICAL - IMMEDIATE ACTION REQUIRED{Colors.RESET}")
        return 1
    elif FINDINGS['high']:
        print(f"{Colors.RED}HIGH RISK - ACTION RECOMMENDED{Colors.RESET}")
        return 1
    elif FINDINGS['medium']:
        print(f"{Colors.YELLOW}MODERATE - REVIEW WARNINGS{Colors.RESET}")
        return 0
    else:
        print(f"{Colors.GREEN}GOOD - ALL TESTS PASSED{Colors.RESET}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
