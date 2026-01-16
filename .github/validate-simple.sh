#!/bin/bash
echo "=== ORCHAT SIMPLE VALIDATION ==="
echo "1. Checking file structure..."
ls -la bin/ src/

echo ""
echo "2. Checking main executable..."
chmod +x bin/orchat
./bin/orchat --help

echo ""
echo "3. Checking dependencies..."
which curl && curl --version | head -1
which jq && jq --version
which python3 && python3 --version

echo ""
echo "4. Testing basic functionality..."
if [ -f "validation/fast-test.sh" ]; then
    ./validation/fast-test.sh
else
    echo "No fast-test.sh found, basic validation complete."
fi

echo "=== VALIDATION COMPLETE ==="
