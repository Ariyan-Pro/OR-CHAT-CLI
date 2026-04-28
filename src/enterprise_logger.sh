#!/bin/bash
#===============================================================================
# ORCHAT Enterprise Logger - 13-Level Logging Hierarchy
# Implements logging levels from QUANTUM (Level -1) to BLACKHOLE (Level 11)
# 
# Levels:
#   -1: QUANTUM    - Sub-atomic debugging, variable state snapshots
#    0: TRACE      - Function entry/exit points
#    1: DEBUG      - Debugging information
#    2: VERBOSE    - Detailed operational information
#    3: INFO       - General informational messages
#    4: NOTICE     - Normal but significant events
#    5: WARNING    - Warning conditions
#    6: ERROR      - Error conditions
#    7: CRITICAL   - Critical conditions
#    8: ALERT      - Action must be taken immediately
#    9: EMERGENCY  - System is unusable
#   10: SILENT     - Suppress all output
#   11: BLACKHOLE  - Complete suppression, no logging whatsoever
#
# Usage:
#   source enterprise_logger.sh
#   log_init "myapp"                    # Initialize with app name
#   log_set_level INFO                  # Set minimum log level
#   log_info "Message here"             # Log at INFO level
#   log_quantum "var=$var"              # Log at QUANTUM level
#===============================================================================

# Prevent multiple sourcing
if [[ -n "${__ENTERPRISE_LOGGER_LOADED:-}" ]]; then
    return 0
fi
__ENTERPRISE_LOGGER_LOADED=1

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
readonly LOG_LEVELS=(
    "QUANTUM"      # -1: Sub-atomic debugging
    "TRACE"        #  0: Function entry/exit
    "DEBUG"        #  1: Debugging info
    "VERBOSE"      #  2: Detailed operations
    "INFO"         #  3: General info
    "NOTICE"       #  4: Significant events
    "WARNING"      #  5: Warnings
    "ERROR"        #  6: Errors
    "CRITICAL"     #  7: Critical conditions
    "ALERT"        #  8: Immediate action needed
    "EMERGENCY"    #  9: System unusable
    "SILENT"       # 10: Suppress output
    "BLACKHOLE"    # 11: Complete suppression
)

# Default configuration
: "${ORCHAT_LOG_DIR:=$HOME/.orchat/logs}"
: "${ORCHAT_LOG_LEVEL:=3}"  # Default to INFO
: "${ORCHAT_LOG_FORMAT:='[%LEVEL%] [%TIMESTAMP%] %MESSAGE%'}"
: "${ORCHAT_LOG_FILE:=''}"
: "${ORCHAT_LOG_CONSOLE:=true}"
: "${ORCHAT_LOG_FILE_ENABLED:=true}"
: "${ORCHAT_LOG_MAX_SIZE:=10485760}"  # 10MB
: "${ORCHAT_LOG_MAX_FILES:=5}"
: "${ORCHAT_LOG_COLOR:=true}"

# Internal state
declare -g __LOG_APP_NAME="orchat"
declare -g __LOG_CURRENT_LEVEL=${ORCHAT_LOG_LEVEL}
declare -g __LOG_FILE_PATH=""
declare -g __LOG_ROTATION_COUNT=0

#-------------------------------------------------------------------------------
# Color Codes for Console Output
#-------------------------------------------------------------------------------
declare -A LOG_COLORS=(
    [QUANTUM]="\033[90m"      # Bright black (gray)
    [TRACE]="\033[36m"        # Cyan
    [DEBUG]="\033[34m"        # Blue
    [VERBOSE]="\033[32m"      # Green
    [INFO]="\033[37m"         # White
    [NOTICE]="\033[33m"       # Yellow
    [WARNING]="\033[93m"      # Bright yellow
    [ERROR]="\033[31m"        # Red
    [CRITICAL]="\033[91m"     # Bright red
    [ALERT]="\033[35m"        # Magenta
    [EMERGENCY]="\033[95m"    # Bright magenta
    [SILENT]="\033[0m"        # No color
    [BLACKHOLE]="\033[0m"     # No color
)
readonly COLOR_RESET="\033[0m"

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

# Get level number from name
log_level_to_num() {
    local level_name="${1^^}"
    case "$level_name" in
        QUANTUM)   echo -1 ;;
        TRACE)     echo 0 ;;
        DEBUG)     echo 1 ;;
        VERBOSE)   echo 2 ;;
        INFO)      echo 3 ;;
        NOTICE)    echo 4 ;;
        WARNING)   echo 5 ;;
        ERROR)     echo 6 ;;
        CRITICAL)  echo 7 ;;
        ALERT)     echo 8 ;;
        EMERGENCY) echo 9 ;;
        SILENT)    echo 10 ;;
        BLACKHOLE) echo 11 ;;
        *)         echo 3 ;;  # Default to INFO
    esac
}

# Get level name from number
log_num_to_level() {
    local level_num=$1
    if [[ $level_num -lt 0 ]]; then
        echo "QUANTUM"
    elif [[ $level_num -gt 11 ]]; then
        echo "BLACKHOLE"
    elif [[ $level_num -eq -1 ]]; then
        echo "QUANTUM"
    else
        # Adjust for -1 offset (QUANTUM is at index 0 but represents -1)
        local adjusted_idx=$((level_num + 1))
        echo "${LOG_LEVELS[$adjusted_idx]}"
    fi
}

# Check if message should be logged based on current level
_should_log() {
    local msg_level=$1
    [[ $msg_level -ge $__LOG_CURRENT_LEVEL ]] && [[ $__LOG_CURRENT_LEVEL -lt 11 ]]
}

# Get formatted timestamp
_get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S.%3N'
}

# Get caller information
_get_caller_info() {
    local frame_depth=${1:-2}
    local caller_file="${BASH_SOURCE[$frame_depth]:-unknown}"
    local caller_line="${BASH_LINENO[$((frame_depth-1))]:-0}"
    local caller_func="${FUNCNAME[$frame_depth]:-main}"
    
    # Extract just the filename
    caller_file="${caller_file##*/}"
    
    echo "${caller_file}:${caller_line}:${caller_func}"
}

# Format log message
_format_message() {
    local level_name=$1
    local message=$2
    local timestamp=$(_get_timestamp)
    local caller_info=$(_get_caller_info 3)
    
    local formatted="${ORCHAT_LOG_FORMAT}"
    formatted="${formatted//%LEVEL%/$level_name}"
    formatted="${formatted//%TIMESTAMP%/$timestamp}"
    formatted="${formatted//%MESSAGE%/$message}"
    formatted="${formatted//%CALLER%/$caller_info}"
    formatted="${formatted//%APP%/$__LOG_APP_NAME}"
    formatted="${formatted//%PID%/$$}"
    
    echo "$formatted"
}

# Rotate log file if needed
# SECURITY NOTE: This function has been updated with file locking to prevent TOCTOU race conditions.
# The flock mechanism ensures atomic rotation when multiple processes access the same log file.
_rotate_log() {
    [[ -z "$__LOG_FILE_PATH" ]] && return 0
    [[ ! -f "$__LOG_FILE_PATH" ]] && return 0
    
    # Use file descriptor locking to prevent race conditions during size check and rotation
    exec 200>"$__LOG_FILE_PATH.lock"
    flock -n 200 || {
        # Another process is rotating, skip this rotation attempt
        return 0
    }
    
    local file_size
    file_size=$(stat -f%z "$__LOG_FILE_PATH" 2>/dev/null || stat -c%s "$__LOG_FILE_PATH" 2>/dev/null || echo 0)
    
    if [[ $file_size -ge $ORCHAT_LOG_MAX_SIZE ]]; then
        local base_name="$__LOG_FILE_PATH"
        local dir_name=$(dirname "$base_name")
        local file_name=$(basename "$base_name")
        
        # Rotate existing files
        for i in $(seq $((ORCHAT_LOG_MAX_FILES - 1)) -1 1); do
            [[ -f "${base_name}.$i" ]] && mv "${base_name}.$i" "${base_name}.$((i + 1))"
        done
        
        # Move current to .1
        mv "$__LOG_FILE_PATH" "${base_name}.1"
        
        # Create new empty file
        touch "$__LOG_FILE_PATH"
        
        ((++__LOG_ROTATION_COUNT))
        log_notice "Log file rotated (rotation #$__LOG_ROTATION_COUNT)"
    fi
    
    # Release lock
    flock -u 200
    exec 200>&-
}

#-------------------------------------------------------------------------------
# Core Logging Functions
#-------------------------------------------------------------------------------

# Initialize logging system
log_init() {
    local app_name="${1:-orchat}"
    local custom_level="${2:-}"
    
    __LOG_APP_NAME="$app_name"
    
    # Create log directory
    if [[ "$ORCHAT_LOG_FILE_ENABLED" == "true" ]]; then
        mkdir -p "$ORCHAT_LOG_DIR" 2>/dev/null || true
        
        if [[ -n "$ORCHAT_LOG_FILE" ]]; then
            __LOG_FILE_PATH="$ORCHAT_LOG_FILE"
        else
            __LOG_FILE_PATH="$ORCHAT_LOG_DIR/${app_name}_$(date '+%Y%m%d').log"
        fi
        
        touch "$__LOG_FILE_PATH" 2>/dev/null || {
            ORCHAT_LOG_FILE_ENABLED=false
            log_warning "Cannot write to log file: $__LOG_FILE_PATH"
        }
    fi
    
    # Set custom level if provided
    if [[ -n "$custom_level" ]]; then
        log_set_level "$custom_level"
    fi
    
    log_debug "Logging initialized for '$app_name' at level $(log_num_to_level $__LOG_CURRENT_LEVEL)"
}

# Set minimum log level
log_set_level() {
    local level="$1"
    local level_num
    
    # Accept either name or number
    if [[ "$level" =~ ^[0-9]+$ ]]; then
        level_num=$level
    else
        level_num=$(log_level_to_num "$level")
    fi
    
    # Clamp to valid range
    [[ $level_num -lt -1 ]] && level_num=-1
    [[ $level_num -gt 11 ]] && level_num=11
    
    __LOG_CURRENT_LEVEL=$level_num
    log_debug "Log level set to $(log_num_to_level $level_num) ($level_num)"
}

# Get current log level
log_get_level() {
    echo "$__LOG_CURRENT_LEVEL"
}

# Write log entry
_log_entry() {
    local level_name=$1
    local level_num=$2
    local message=$3
    
    # Check if we should log this level
    _should_log $level_num || return 0
    
    # BLACKHOLE suppresses everything
    [[ $level_num -eq 11 ]] && return 0
    
    # SILENT suppresses everything except emergencies
    [[ $level_num -eq 10 ]] && [[ $level_num -ne 9 ]] && return 0
    
    local formatted_msg
    formatted_msg=$(_format_message "$level_name" "$message")
    
    # Console output
    if [[ "$ORCHAT_LOG_CONSOLE" == "true" ]] && [[ $level_num -lt 10 ]]; then
        local color="${LOG_COLORS[$level_name]:-$COLOR_RESET}"
        if [[ "$ORCHAT_LOG_COLOR" == "true" ]]; then
            echo -e "${color}${formatted_msg}${COLOR_RESET}" >&2
        else
            echo "$formatted_msg" >&2
        fi
    fi
    
    # File output
    if [[ "$ORCHAT_LOG_FILE_ENABLED" == "true" ]] && [[ -n "$__LOG_FILE_PATH" ]]; then
        # Remove color codes for file output
        local clean_msg
        clean_msg=$(echo -e "$formatted_msg" | sed 's/\x1b\[[0-9;]*m//g')
        
        echo "$clean_msg" >> "$__LOG_FILE_PATH"
        
        # Check for rotation
        _rotate_log
    fi
}

#-------------------------------------------------------------------------------
# Public Logging API - 13 Levels
#-------------------------------------------------------------------------------

# Level -1: QUANTUM - Sub-atomic debugging, variable state snapshots
log_quantum() {
    local message="$*"
    _log_entry "QUANTUM" -1 "🔬 $message"
}

# Level 0: TRACE - Function entry/exit points
log_trace() {
    local message="$*"
    _log_entry "TRACE" 0 "📍 $message"
}

# Level 1: DEBUG - Debugging information
log_debug() {
    local message="$*"
    _log_entry "DEBUG" 1 "🐛 $message"
}

# Level 2: VERBOSE - Detailed operational information
log_verbose() {
    local message="$*"
    _log_entry "VERBOSE" 2 "📋 $message"
}

# Level 3: INFO - General informational messages
log_info() {
    local message="$*"
    _log_entry "INFO" 3 "ℹ️  $message"
}

# Level 4: NOTICE - Normal but significant events
log_notice() {
    local message="$*"
    _log_entry "NOTICE" 4 "📌 $message"
}

# Level 5: WARNING - Warning conditions
log_warning() {
    local message="$*"
    _log_entry "WARNING" 5 "⚠️  $message"
}

# Level 6: ERROR - Error conditions
log_error() {
    local message="$*"
    _log_entry "ERROR" 6 "❌ $message"
}

# Level 7: CRITICAL - Critical conditions
log_critical() {
    local message="$*"
    _log_entry "CRITICAL" 7 "🔴 $message"
}

# Level 8: ALERT - Action must be taken immediately
log_alert() {
    local message="$*"
    _log_entry "ALERT" 8 "🚨 $message"
}

# Level 9: EMERGENCY - System is unusable
log_emergency() {
    local message="$*"
    _log_entry "EMERGENCY" 9 "💥 $message"
}

# Level 10: SILENT - Suppress all output (no-op by design)
log_silent() {
    : # Intentionally does nothing
}

# Level 11: BLACKHOLE - Complete suppression (no-op by design)
log_blackhole() {
    : # Intentionally does nothing
}

#-------------------------------------------------------------------------------
# Advanced Logging Features
#-------------------------------------------------------------------------------

# Log with structured data (JSON-like)
log_structured() {
    local level="${1:-INFO}"
    local event="$2"
    shift 2
    local data="$*"
    
    local timestamp=$(_get_timestamp)
    local structured_msg="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"event\":\"$event\",\"data\":$data}"
    
    local level_num
    level_num=$(log_level_to_num "$level")
    _log_entry "$level" "$level_num" "$structured_msg"
}

# Log function entry (convenience wrapper)
log_enter() {
    local func_name="${1:-${FUNCNAME[1]}}"
    local args="$2"
    log_trace "➡️  ENTER: $func_name($args)"
}

# Log function exit (convenience wrapper)
log_exit() {
    local func_name="${1:-${FUNCNAME[1]}}"
    local result="$2"
    log_trace "⬅️  EXIT: $func_name -> $result"
}

# Log variable state (quantum-level debugging)
log_var() {
    local var_name="$1"
    local var_value="${!1}"
    log_quantum "VAR[$var_name] = '$var_value'"
}

# Log execution time
log_duration() {
    local operation="$1"
    local start_time="$2"
    local end_time="${3:-$(date +%s.%N)}"
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    log_verbose "⏱️  $operation completed in ${duration}s"
}

# Conditional logging
# SECURITY NOTE: condition parameter should only contain safe boolean expressions
# Usage: log_if '[[ $DEBUG == true ]]' INFO "message"
log_if() {
    local condition="$1"
    local level="$2"
    shift 2
    local message="$*"
    
    # Validate condition contains only safe characters (alphanumeric, spaces, brackets, operators, $ for variables)
    # Allow: letters, numbers, spaces, tabs, brackets, =, !, &, |, quotes, hyphens, underscores, dollar signs
    if [[ ! "$condition" =~ ^[[:space:]a-zA-Z0-9_\[\]\=\!\&\|\'\"\$\-\>\<\#\*\?]+$ ]]; then
        _log_entry "ERROR" "7" "[SECURITY] Invalid condition format in log_if"
        return 1
    fi
    
    # Additional check: reject dangerous patterns
    if [[ "$condition" =~ [\`\;\(\)] ]] || [[ "$condition" =~ \$\( ]] || [[ "$condition" =~ \`.*\` ]]; then
        _log_entry "ERROR" "7" "[SECURITY] Dangerous pattern detected in log_if condition"
        return 1
    fi
    
    if eval "$condition"; then
        local level_num
        level_num=$(log_level_to_num "$level")
        _log_entry "$level" "$level_num" "$message"
    fi
}

# One-time logging (only logs first occurrence)
declare -A __LOGGED_ONCE=()
log_once() {
    local key="$1"
    local level="$2"
    shift 2
    local message="$*"
    
    if [[ -z "${__LOGGED_ONCE[$key]:-}" ]]; then
        __LOGGED_ONCE[$key]=1
        local level_num
        level_num=$(log_level_to_num "$level")
        _log_entry "$level" "$level_num" "$message"
    fi
}

# Rate-limited logging (max N times per minute)
declare -A __LOG_RATE_LIMIT=()
log_rate_limited() {
    local key="$1"
    local max_count="${2:-5}"
    local level="$3"
    shift 3
    local message="$*"
    
    local current_minute
    current_minute=$(date '+%Y%m%d%H%M')
    local cache_key="${key}_${current_minute}"
    
    local count="${__LOG_RATE_LIMIT[$cache_key]:-0}"
    
    if [[ $count -lt $max_count ]]; then
        ((++count))
        __LOG_RATE_LIMIT[$cache_key]=$count
        local level_num
        level_num=$(log_level_to_num "$level")
        _log_entry "$level" "$level_num" "$message"
    elif [[ $count -eq $max_count ]]; then
        ((++count))
        __LOG_RATE_LIMIT[$cache_key]=$count
        log_once "rate_limit_$key" WARNING "Rate limit exceeded for '$key' (> $max_count/min)"
    fi
}

#-------------------------------------------------------------------------------
# Metrics and Statistics
#-------------------------------------------------------------------------------

# Get logging statistics
log_stats() {
    local total_entries=0
    local file_entries=0
    
    if [[ -n "$__LOG_FILE_PATH" ]] && [[ -f "$__LOG_FILE_PATH" ]]; then
        file_entries=$(wc -l < "$__LOG_FILE_PATH" 2>/dev/null || echo 0)
    fi
    
    cat <<EOF
=== ORCHAT Enterprise Logger Statistics ===
Application:     $__LOG_APP_NAME
Current Level:   $(log_num_to_level $__LOG_CURRENT_LEVEL) ($__LOG_CURRENT_LEVEL)
Log Directory:   $ORCHAT_LOG_DIR
Log File:        $__LOG_FILE_PATH
File Rotation:   $__LOG_ROTATION_COUNT
Console Output:  $ORCHAT_LOG_CONSOLE
File Logging:    $ORCHAT_LOG_FILE_ENABLED
Color Output:    $ORCHAT_LOG_COLOR
Max File Size:   $ORCHAT_LOG_MAX_SIZE bytes
Max Files:       $ORCHAT_LOG_MAX_FILES
Total Lines:     $file_entries
===========================================
EOF
}

# Reset rate limiting counters
log_reset_rate_limits() {
    __LOG_RATE_LIMIT=()
    log_debug "Rate limit counters reset"
}

#-------------------------------------------------------------------------------
# Cleanup and Shutdown
#-------------------------------------------------------------------------------

# Final log entry before shutdown
log_shutdown() {
    log_notice "🏁 Logger shutting down for $__LOG_APP_NAME"
    log_stats >&2
}

# Auto-register shutdown hook
trap 'log_shutdown 2>/dev/null' EXIT

#-------------------------------------------------------------------------------
# Initialization
#-------------------------------------------------------------------------------

# Auto-initialize if sourced directly with APP_NAME set
if [[ -n "${ORCHAT_APP_NAME:-}" ]]; then
    log_init "$ORCHAT_APP_NAME" "${ORCHAT_LOG_LEVEL:-3}"
fi

# Export public functions
export -f log_init log_set_level log_get_level
export -f log_quantum log_trace log_debug log_verbose log_info
export -f log_notice log_warning log_error log_critical log_alert log_emergency
export -f log_silent log_blackhole
export -f log_structured log_enter log_exit log_var log_duration
export -f log_if log_once log_rate_limited
export -f log_stats log_reset_rate_limits log_shutdown

# Display welcome message at appropriate level
if [[ "${ORCHAT_QUIET:-false}" != "true" ]]; then
    log_debug "Enterprise Logger v1.0.4 loaded - 13-level hierarchy active"
fi
