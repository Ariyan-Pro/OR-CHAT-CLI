#!/usr/bin/env python3
"""ORCHAT Python CLI Wrapper - Security Hardened"""

import os
import sys
import subprocess
import re

def validate_argument(arg):
    """Validate argument for security issues"""
    # Check for path traversal
    if '..' in arg:
        return False
    # Check for shell injection patterns
    dangerous_patterns = ['$(', '`', ';', '|', '&', '>', '<', '\n', '\r']
    for pattern in dangerous_patterns:
        if pattern in arg:
            return False
    return True

def main():
    """Main entry point for Python package"""
    # Find the bash script
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bash_script = os.path.join(script_dir, "bin", "orchat")
    
    if not os.path.exists(bash_script):
        print("ERROR: ORCHAT bash script not found")
        sys.exit(1)
    
    # Security: Validate all arguments before passing to bash script
    for i, arg in enumerate(sys.argv[1:], 1):
        if not validate_argument(arg):
            print(f"ERROR: Invalid argument detected at position {i}")
            print("Arguments containing path traversal or shell injection patterns are not allowed")
            sys.exit(1)
    
    # Execute the bash script with all arguments
    cmd = [bash_script] + sys.argv[1:]
    result = subprocess.run(cmd)
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()
