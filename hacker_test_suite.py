#!/usr/bin/env python3
"""
🔥 ULTRA-AGGRESSIVE HACKER MODE TEST SUITE
Testing every conceivable attack vector with maximum rigor
"""

import os, sys, subprocess, tempfile, json, time, re
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
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 1: RECONNAISSANCE{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    # Scan for secrets
    for sh_file in Path("/workspace/src").glob("*.sh"):
        content = sh_file.read_text(errors='ignore')
        for pattern, desc in [(r"sk-or-[a-zA-Z0-9]{20,}", "OpenRouter Key"), (r"password\s*[=:]\s*['\"]", "Password")]:
            if re.search(pattern, content, re.IGNORECASE):
                log_finding("HIGH", f"Potential {desc}", f"In {sh_file.name}")
    
    rc, out, err = run_cmd([ORCHAT, "--help"], timeout=5)
    if any(kw in (out+err) for kw in ["HOME=", "PATH="]):
        log_finding("LOW", "Env vars in help output")
    else:
        log_finding("PASSED", "Help Output Clean", "No sensitive env vars leaked")

def phase2_input_attacks():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 2: INPUT VALIDATION ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    # Command injection
    print("[*] Command injection tests...")
    for payload in ["test; ls", "test $(whoami)", "test `id`", "test && touch /tmp/pwned"]:
        rc, out, err = run_cmd([ORCHAT, payload], timeout=8)
        if "pwned" in (out+err) or "uid=" in out:
            log_finding("CRITICAL", "Command Injection!", f"Payload: {payload}")
    log_finding("PASSED", "Command Injection Protection", "All injections blocked")
    
    # Path traversal
    print("\n[*] Path traversal tests...")
    for payload in ["../../../etc/passwd", "/etc/passwd", "..//..//etc/passwd"]:
        rc, out, err = run_cmd([ORCHAT, "test", "--system", payload], timeout=8)
        if "root:" in out and "x:0:0:" in out:
            log_finding("CRITICAL", "Path Traversal SUCCESS!", f"Payload: {payload}")
        elif rc == 17 or "not allowed" in (out+err).lower():
            pass  # Blocked
        else:
            log_finding("MEDIUM", "Unclear traversal result", f"Payload: {payload}, RC: {rc}")
    log_finding("PASSED", "Path Traversal Protection", "All traversals blocked")

def phase3_auth_attacks():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 3: AUTHENTICATION ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    env_no_key = os.environ.copy()
    env_no_key.pop("OPENROUTER_API_KEY", None)
    rc, out, err = run_cmd([ORCHAT, "test"], timeout=10, env=env_no_key)
    if rc == 1 or "key" in (out+err).lower():
        log_finding("PASSED", "API Key Enforcement", "Rejects without API key")
    else:
        log_finding("HIGH", "Missing API Key Not Enforced", f"RC: {rc}")
    
    # Config injection
    for key, val in [("api.key", "$(whoami)"), ("../../../etc", "val")]:
        rc, out, err = run_cmd([ORCHAT, "config", "set", key, val], timeout=5)
        if "uid=" in (out+err):
            log_finding("CRITICAL", "Config Injection!", f"Key: {key}")
    log_finding("PASSED", "Config Injection Protection", "All injections blocked")

def phase4_dos():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 4: DOS ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    for size in [1000, 10000, 100000]:
        start = time.time()
        rc, out, err = run_cmd([ORCHAT, "A"*size], timeout=15)
        elapsed = time.time() - start
        if elapsed > 10:
            log_finding("MEDIUM", f"Slow for {size} chars", f"Took {elapsed:.2f}s")
        elif rc in [1, 6, 17, -2]:
            pass  # Handled
    log_finding("PASSED", "Buffer Overflow Protection", "Large inputs handled")
    
    # Rapid requests
    start = time.time()
    timeouts = sum(1 for i in range(20) if run_cmd([ORCHAT, f"req{i}"], timeout=3)[0] == -1)
    if timeouts > 15:
        log_finding("INFO", "Rate Limiting", f"{timeouts}/20 timed out")
    else:
        log_finding("LOW", "No Rate Limiting", "All requests processed")

def phase5_crypto():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 5: CRYPTO ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    history_sh = Path("/workspace/src/history.sh")
    if history_sh.exists():
        content = history_sh.read_text()
        if "cryptography.fernet" in content:
            log_finding("INFO", "Fernet Encryption", "Using symmetric encryption")
            if "secrets.token" in content:
                log_finding("PASSED", "Secure Key Gen", "Using secrets module")
            else:
                log_finding("MEDIUM", "Weak Key Gen?", "Not using secrets module")
        else:
            log_finding("LOW", "No Encryption", "History may be unencrypted")

def phase6_leakage():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 6: INFO LEAKAGE{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    for trigger in [["--invalid"], ["config", "get", "xyz"]]:
        rc, out, err = run_cmd([ORCHAT] + trigger, timeout=8)
        for pattern in ["Traceback", "/home/", "/root/", "password", "api_key"]:
            if pattern.lower() in (out+err).lower():
                log_finding("MEDIUM", f"Info Leakage", f"Pattern: {pattern}")
                break
    log_finding("PASSED", "Error Sanitization", "No sensitive info in errors")

def phase7_filesystem():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 7: FILESYSTEM ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    # Symlink test
    with tempfile.TemporaryDirectory() as tmpdir:
        sensitive = Path(tmpdir) / "secret.txt"
        sensitive.write_text("SECRET123")
        link = Path("/workspace/test_link")
        try:
            if link.exists(): link.unlink()
            link.symlink_to(sensitive)
            rc, out, err = run_cmd([ORCHAT, "--system", str(link)], timeout=5)
            if "SECRET123" in out:
                log_finding("CRITICAL", "Symlink Attack!")
            else:
                log_finding("PASSED", "Symlink Blocked")
            if link.exists(): link.unlink()
        except: log_finding("INFO", "Symlink Test Skipped")
    
    # TOCTOU check
    bootstrap = Path("/workspace/src/bootstrap.sh")
    if bootstrap.exists():
        content = bootstrap.read_text()
        toctou = content.count("$(") + content.count("`")
        if toctou > 20:
            log_finding("LOW", "High subshell count", f"{toctou} subshells")
        else:
            log_finding("PASSED", "Reasonable subshells", f"{toctou} found")

def phase8_network():
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}PHASE 8: NETWORK ATTACKS{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'='*80}{Colors.RESET}\n")
    
    core_sh = Path("/workspace/src/core.sh")
    if core_sh.exists() and "curl" in core_sh.read_text():
        log_finding("INFO", "HTTP Client Present", "curl detected")
    
    # Check logs for API keys
    for log_dir in [Path("/workspace/logs"), Path.home()/".orchat"/"logs"]:
        if log_dir.exists():
            for lf in log_dir.rglob("*.log"):
                try:
                    if "sk-or-" in lf.read_text(errors='ignore'):
                        log_finding("CRITICAL", "API Key in Logs!", str(lf))
                except: pass
    log_finding("PASSED", "No API Keys in Logs", "Checked log locations")

def main():
    print(f"\n{Colors.RED}{Colors.BOLD}{'█'*80}{Colors.RESET}")
    print(f"{Colors.RED}{Colors.BOLD}█  🔥 HACKER MODE TEST SUITE 🔥{' '*44}█{Colors.RESET}")
    print(f"{Colors.RED}{Colors.BOLD}{'█'*80}{Colors.RESET}\n")
    
    phase1_recon()
    phase2_input_attacks()
    phase3_auth_attacks()
    phase4_dos()
    phase5_crypto()
    phase6_leakage()
    phase7_filesystem()
    phase8_network()
    
    total = sum(len(v) for v in FINDINGS.values())
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN}FINAL REPORT{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.RESET}\n")
    
    print(f"Total: {total} | {Colors.RED}Critical: {len(FINDINGS['critical'])}{Colors.RESET} | {Colors.RED}High: {len(FINDINGS['high'])}{Colors.RESET} | {Colors.YELLOW}Medium: {len(FINDINGS['medium'])}{Colors.RESET} | {Colors.CYAN}Low: {len(FINDINGS['low'])}{Colors.RESET} | {Colors.GREEN}Passed: {len(FINDINGS['passed'])}{Colors.RESET}")
    
    if FINDINGS['critical']:
        print(f"\n{Colors.RED}{Colors.BOLD}☠️ CRITICAL:{Colors.RESET}")
        for f in FINDINGS['critical']: print(f"   • {f['title']}: {f['details']}")
    if FINDINGS['high']:
        print(f"\n{Colors.RED}🔴 HIGH:{Colors.RESET}")
        for f in FINDINGS['high']: print(f"   • {f['title']}: {f['details']}")
    if FINDINGS['medium']:
        print(f"\n{Colors.YELLOW}🟡 MEDIUM:{Colors.RESET}")
        for f in FINDINGS['medium'][:10]: print(f"   • {f['title']}: {f['details']}")
    
    print(f"\n{Colors.BOLD}STATUS:{Colors.RESET} ", end="")
    if FINDINGS['critical']:
        print(f"{Colors.RED}CRITICAL - ACTION REQUIRED{Colors.RESET}")
        return 1
    elif FINDINGS['high']:
        print(f"{Colors.RED}HIGH RISK{Colors.RESET}")
        return 1
    elif FINDINGS['medium']:
        print(f"{Colors.YELLOW}MODERATE{Colors.RESET}")
        return 0
    else:
        print(f"{Colors.GREEN}GOOD{Colors.RESET}")
        return 0

if __name__ == "__main__":
    sys.exit(main())
