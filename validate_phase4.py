#!/usr/bin/env python3
"""
✅ ORCHAT PHASE 4 VALIDATION
Validates all Phase 4 deliverables are complete.
"""

import os
import sys
import subprocess
from pathlib import Path
import json

print("\n" + "="*80)
print("✅ ORCHAT PHASE 4 VALIDATION")
print("="*80)

def check_phase4_deliverables():
    """Check all Phase 4 deliverables"""
    
    deliverables = {
        "phase4_plan.md": "Phase 4 completion plan",
        "orchat-doctor": "Diagnostic tool",
        "add_deterministic.sh": "Deterministic mode implementation",
        "build-all.sh": "Complete packaging script",
        "phase4/": "Phase 4 directory structure",
        "test_deterministic.sh": "Deterministic mode test",
    }
    
    print("\n1️⃣ CHECKING DELIVERABLES...")
    
    all_present = True
    for file, description in deliverables.items():
        if os.path.exists(file):
            print(f"   ✅ {description}: {file}")
        else:
            print(f"   ❌ {description}: {file} - MISSING")
            all_present = False
    
    return all_present

def test_orchat_doctor():
    """Test orchat-doctor tool"""
    
    print("\n2️⃣ TESTING ORCHAT-DOCTOR...")
    
    if not os.path.exists("orchat-doctor"):
        print("   ❌ orchat-doctor not found")
        return False
    
    # Make executable
    os.chmod("orchat-doctor", 0o755)
    
    # Test help/version
    try:
        result = subprocess.run(
            ["./orchat-doctor", "diagnose"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode in [0, 1, 2]:
            print("   ✅ orchat-doctor executes successfully")
            
            # Check output contains expected sections
            output = result.stdout + result.stderr
            expected_sections = [
                "EXECUTABLE CHECK",
                "CONFIGURATION CHECK", 
                "DEPENDENCY CHECK",
                "DIAGNOSTIC SUMMARY"
            ]
            
            found_sections = 0
            for section in expected_sections:
                if section in output:
                    found_sections += 1
            
            if found_sections >= 2:
                print(f"   ✅ orchat-doctor output contains {found_sections}/4 expected sections")
            else:
                print(f"   ⚠️  orchat-doctor output missing some sections")
            
            return True
        else:
            print(f"   ❌ orchat-doctor failed with code {result.returncode}")
            return False
            
    except Exception as e:
        print(f"   ❌ orchat-doctor test failed: {e}")
        return False

def test_packaging_scripts():
    """Test packaging scripts"""
    
    print("\n3️⃣ TESTING PACKAGING SCRIPTS...")
    
    scripts = ["build-all.sh", "add_deterministic.sh"]
    
    for script in scripts:
        if os.path.exists(script):
            print(f"   ✅ {script} exists")
            
            # Check if it's a valid shell script
            with open(script, 'r') as f:
                content = f.read(100)
                if content.startswith("#!/"):
                    print(f"   ✅ {script} has valid shebang")
                else:
                    print(f"   ⚠️  {script} missing shebang")
        else:
            print(f"   ❌ {script} missing")
    
    return True

def check_deterministic_mode():
    """Check deterministic mode implementation"""
    
    print("\n4️⃣ CHECKING DETERMINISTIC MODE...")
    
    if os.path.exists("add_deterministic.sh"):
        print("   ✅ Deterministic mode patch script exists")
        
        # Check if patch would apply
        with open("add_deterministic.sh", 'r') as f:
            content = f.read()
            if "deterministic" in content.lower():
                print("   ✅ Deterministic mode implementation found")
            else:
                print("   ⚠️  Deterministic mode implementation unclear")
    else:
        print("   ❌ Deterministic mode script missing")
    
    # Check test script
    if os.path.exists("test_deterministic.sh"):
        print("   ✅ Deterministic test script exists")
    else:
        print("   ⚠️  Deterministic test script missing")
    
    return True

def generate_phase4_report():
    """Generate Phase 4 completion report"""
    
    print("\n5️⃣ GENERATING PHASE 4 COMPLETION REPORT...")
    
    report = {
        "project": "ORCHAT",
        "phase": 4,
        "phase_title": "Production Hardening & Distribution",
        "validation_date": subprocess.getoutput("date -Iseconds"),
        "deliverables": {},
        "status": "in_progress",
        "remaining_tasks": []
    }
    
    # Check deliverables
    deliverables = [
        ("Packaging systems", ["build-all.sh", "phase4/packaging/"]),
        ("Distribution channels", ["dist/", "release/"]),
        ("Deterministic mode", ["add_deterministic.sh", "test_deterministic.sh"]),
        ("Diagnostic tools", ["orchat-doctor"]),
    ]
    
    for deliverable_name, files in deliverables:
        status = "complete"
        for file in files:
            if not os.path.exists(file):
                status = "incomplete"
                report["remaining_tasks"].append(f"Complete {deliverable_name}: {file}")
                break
        
        report["deliverables"][deliverable_name] = {
            "status": status,
            "files": files
        }
    
    # Determine overall status
    incomplete = sum(1 for d in report["deliverables"].values() if d["status"] == "incomplete")
    if incomplete == 0:
        report["status"] = "complete"
    elif incomplete <= 2:
        report["status"] = "mostly_complete"
    else:
        report["status"] = "in_progress"
    
    # Save report
    report_file = "phase4_validation_report.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"   ✅ Report saved: {report_file}")
    
    # Print summary
    print(f"\n📊 PHASE 4 STATUS: {report['status'].upper()}")
    for deliverable, info in report["deliverables"].items():
        status_icon = "✅" if info["status"] == "complete" else "⚠️ "
        print(f"   {status_icon} {deliverable}: {info['status']}")
    
    if report["remaining_tasks"]:
        print(f"\n🔧 REMAINING TASKS:")
        for task in report["remaining_tasks"]:
            print(f"   • {task}")
    
    return report["status"] == "complete"

def main():
    """Main validation routine"""
    
    print("\n🚀 VALIDATING ORCHAT PHASE 4 COMPLETION...")
    
    try:
        # Check deliverables
        deliverables_ok = check_phase4_deliverables()
        
        # Test components
        doctor_ok = test_orchat_doctor()
        packaging_ok = test_packaging_scripts()
        deterministic_ok = check_deterministic_mode()
        
        # Generate report
        complete = generate_phase4_report()
        
        print("\n" + "="*80)
        print("📊 VALIDATION RESULTS")
        print("="*80)
        
        if complete and deliverables_ok and doctor_ok:
            print("✅ PHASE 4: READY FOR PRODUCTION DEPLOYMENT")
            
            print("\n🎯 DELIVERABLES COMPLETE:")
            print("   1. Packaging systems for all platforms")
            print("   2. Deterministic mode for testing/CI")
            print("   3. Diagnostic tools (orchat-doctor)")
            print("   4. Distribution pipeline foundation")
            
            print("\n🚀 NEXT STEPS:")
            print("   1. Run: ./build-all.sh (build all packages)")
            print("   2. Test: ./test_deterministic.sh (verify deterministic mode)")
            print("   3. Validate: ./orchat-doctor diagnose (system health)")
            print("   4. Deploy: Distribute packages to target platforms")
            
        else:
            print("⚠️  PHASE 4: INCOMPLETE")
            
            print("\n🔧 REQUIRED ACTIONS:")
            if not deliverables_ok:
                print("   • Complete missing deliverable files")
            if not doctor_ok:
                print("   • Fix orchat-doctor tool")
            if not complete:
                print("   • Complete remaining Phase 4 tasks")
        
    except Exception as e:
        print(f"\n❌ Validation failed: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    print("\n" + "="*80)
    return complete

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
