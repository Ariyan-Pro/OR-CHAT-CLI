#!/usr/bin/env python3
"""ORCHAT Python CLI Wrapper"""

import os
import sys
import subprocess

def main():
    """Main entry point for Python package"""
    # Find the bash script
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bash_script = os.path.join(script_dir, "bin", "orchat")
    
    if os.path.exists(bash_script):
        # Execute the bash script with all arguments
        cmd = [bash_script] + sys.argv[1:]
        subprocess.run(cmd)
    else:
        print("ERROR: ORCHAT bash script not found")
        sys.exit(1)

if __name__ == "__main__":
    main()
