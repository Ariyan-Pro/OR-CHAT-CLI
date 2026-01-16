#!/usr/bin/env bats
# workspace.bats - Phase 5.0 Step 1 Tests
# 50+ years: If it isn't tested, it's broken

setup() {
    # Create test directories
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
}

teardown() {
    # Cleanup
    cd /
    rm -rf "$TEST_DIR"
}

@test "detect_root finds git repo" {
    # Create a git repo
    mkdir -p project/src
    cd project
    git init >/dev/null 2>&1
    touch README.md
    
    run source /mnt/c/Users/dell/Projects/orchat/src/workspace/detect_root.sh "$(pwd)"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$(pwd)" ]
    [ "${lines[1]}" = "git" ]
}

@test "detect_root finds python project" {
    # Create python project
    mkdir -p pyproject/src
    cd pyproject
    touch pyproject.toml
    
    run source /mnt/c/Users/dell/Projects/orchat/src/workspace/detect_root.sh "$(pwd)"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$(pwd)" ]
    [ "${lines[1]}" = "python" ]
}

@test "detect_root falls back to current directory" {
    # Empty directory
    mkdir -p empty
    cd empty
    
    run source /mnt/c/Users/dell/Projects/orchat/src/workspace/detect_root.sh "$(pwd)"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "$(pwd)" ]
    [ "${lines[1]}" = "unknown" ]
}

@test "ignore patterns load correctly" {
    # Create test ignore files
    mkdir -p testproject
    cd testproject
    
    echo "*.log" > .gitignore
    echo "temp/" > .orchatignore
    
    run source /mnt/c/Users/dell/Projects/orchat/src/workspace/ignore.sh
    run load_ignore_rules "$(pwd)"
    
    [ "$status" -eq 0 ]
    # Should contain both patterns
    [[ "$output" == *"*.log"* ]]
    [[ "$output" == *"temp/"* ]]
    # Should contain built-in patterns
    [[ "$output" == *".git/"* ]]
    [[ "$output" == *"node_modules/"* ]]
}

@test "should_ignore works correctly" {
    # Load test patterns
    patterns=("*.log" "temp/" ".git/")
    
    source /mnt/c/Users/dell/Projects/orchat/src/workspace/ignore.sh
    
    run should_ignore "test.log" "${patterns[@]}"
    [ "$status" -eq 0 ]
    
    run should_ignore "temp/file.txt" "${patterns[@]}"
    [ "$status" -eq 0 ]
    
    run should_ignore ".git/config" "${patterns[@]}"
    [ "$status" -eq 0 ]
    
    run should_ignore "src/main.py" "${patterns[@]}"
    [ "$status" -eq 1 ]
}

@test "scan_files enumerates git repo files" {
    # Create git repo with files
    mkdir -p gitproject/src
    cd gitproject
    git init >/dev/null 2>&1
    
    touch README.md
    touch src/main.py
    touch test.log  # This should be ignored if in .gitignore
    
    echo "*.log" > .gitignore
    git add . >/dev/null 2>&1
    git commit -m "init" >/dev/null 2>&1
    
    # Load ignore patterns
    source /mnt/c/Users/dell/Projects/orchat/src/workspace/ignore.sh
    patterns=()
    while IFS= read -r pattern; do
        patterns+=("$pattern")
    done < <(load_ignore_rules "$(pwd)")
    
    run source /mnt/c/Users/dell/Projects/orchat/src/workspace/scan_files.sh
    run scan_project_files "$(pwd)" "${patterns[@]}"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"FILE_COUNT:"* ]]
    [[ "$output" == *"README.md"* ]] || [[ "$output" == *"KEY_FILE:README.md"* ]]
}

@test "summarize produces readable output" {
    # Create simple project
    mkdir -p simple/scripts
    cd simple
    touch README.md
    touch scripts/hello.sh
    
    run source /mnt/c/Users/dell/Projects/orchat/src/workspace/summarize.sh
    run summarize_workspace "$(pwd)"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project root:"* ]]
    [[ "$output" == *"Project type:"* ]]
    [[ "$output" == *"Tracked files:"* ]]
    [[ "$output" == *"README.md"* ]]
}

@test "workspace_status completes in reasonable time" {
    # Medium-sized test project
    mkdir -p medium/{src,docs,tests}
    cd medium
    touch README.md
    touch src/{main.py,utils.py}
    touch tests/test_basic.py
    touch pyproject.toml
    
    for i in {1..50}; do
        touch "src/file$i.py"
    done
    
    run source /mnt/c/Users/dell/Projects/orchat/src/workspace.sh
    run workspace_status
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Workspace analysis completed in"* ]]
    # Should complete in less than 500ms even with 50+ files
    [[ "$output" =~ completed\ in\ ([0-9]+)ms ]]
    local duration="${BASH_REMATCH[1]}"
    [ "$duration" -lt 500 ]
}
