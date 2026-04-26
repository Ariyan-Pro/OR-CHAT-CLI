#!/usr/bin/env bash
# shellcheck disable=SC2034
ORCHAT_API_URL="https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL="${ORCHAT_MODEL:-openai/gpt-3.5-turbo}"  # CHANGED: Use WORKING model
DEFAULT_TEMPERATURE="0.7"
DEFAULT_HISTORY_FILE="$HOME/.orchat_history"
DEFAULT_CONFIG_FILE="$HOME/.orchatrc"
VERSION="1.0.4"

# Export exit codes for use in other modules
export E_OK=0 E_INPUT_EMPTY=8 E_INPUT_INVALID=10 E_CONFIG_MISSING=16 E_CONFIG_INVALID=17
export E_AUTH_MISSING=24 E_NET_TIMEOUT=32 E_API_UNAVAILABLE=40

# ============================================================================
# FULL POSIX EXIT CODE RANGE (0-255)
# Enterprise-grade error handling with comprehensive exit codes
# ============================================================================

# Standard Success Codes (0-7)
E_OK=0                              # Success
E_OK_PARTIAL=1                      # Partial success (some operations failed)
E_OK_WARNING=2                      # Success with warnings
E_OK_MODIFIED=3                     # Success, file modified
E_OK_CREATED=4                      # Success, resource created
E_OK_DELETED=5                      # Success, resource deleted
E_OK_UPDATED=6                      # Success, resource updated
E_OK_RESTARTED=7                    # Success, service restarted

# Input/Validation Errors (8-15)
E_INPUT_EMPTY=8                     # Empty input provided
E_INPUT_TOO_LONG=9                  # Input exceeds maximum length
E_INPUT_INVALID=10                  # Invalid input format
E_INPUT_ENCODING=11                 # Input encoding error (BOM, CRLF)
E_INPUT_TRUNCATED=12                # Input was truncated
E_INPUT_SECURITY=13                 # Security violation in input
E_INPUT_TOKEN_LIMIT=14              # Token limit exceeded
E_INPUT_RESERVED=15                 # Reserved for future input errors

# Configuration Errors (16-23)
E_CONFIG_MISSING=16                 # Configuration file missing
E_CONFIG_INVALID=17                 # Invalid configuration format
E_CONFIG_PERMISSION=18              # Configuration permission denied
E_CONFIG_LOCKED=19                  # Configuration file locked
E_CONFIG_DEPRECATED=20              # Deprecated configuration key
E_CONFIG_CONFLICT=21                # Conflicting configuration values
E_CONFIG_RANGE=22                   # Configuration value out of range
E_CONFIG_RESERVED=23                # Reserved for future config errors

# Authentication/Authorization Errors (24-31)
E_AUTH_MISSING=24                   # API key missing
E_AUTH_INVALID=25                   # API key invalid
E_AUTH_EXPIRED=26                   # API key expired
E_AUTH_FORBIDDEN=27                 # Access forbidden
E_AUTH_RATE_LIMIT=28                # Rate limited
E_AUTH_QUOTA=29                     # Quota exceeded
E_AUTH_SCOPE=30                     # Insufficient scope/permissions
E_AUTH_RESERVED=31                  # Reserved for future auth errors

# Network Errors (32-39)
E_NET_TIMEOUT=32                    # Network timeout
E_NET_CONNECTION=33                 # Connection failed
E_NET_DNS=34                        # DNS resolution failed
E_NET_SSL=35                        # SSL/TLS error
E_NET_PROXY=36                      # Proxy error
E_NET_UNREACHABLE=37                # Host unreachable
E_NET_RESET=38                      # Connection reset
E_NET_RESERVED=39                   # Reserved for future network errors

# API/Service Errors (40-47)
E_API_UNAVAILABLE=40                # API unavailable
E_API_VERSION=41                    # API version mismatch
E_API_FORMAT=42                     # API response format error
E_API_SCHEMA=43                     # API schema validation failed
E_API_RATE_LIMIT=44                 # API rate limit exceeded
E_API_QUOTA=45                      # API quota exceeded
E_API_MAINTENANCE=46                # API under maintenance
E_API_RESERVED=47                   # Reserved for future API errors

# Resource Errors (48-55)
E_RESOURCE_NOT_FOUND=48             # Resource not found
E_RESOURCE_EXISTS=49                # Resource already exists
E_RESOURCE_LOCKED=50                # Resource locked
E_RESOURCE_FULL=51                  # Resource full (disk, memory)
E_RESOURCE_QUOTA=52                 # Resource quota exceeded
E_RESOURCE_CORRUPT=53               # Resource corrupted
E_RESOURCE_VERSION=54               # Resource version conflict
E_RESOURCE_RESERVED=55              # Reserved for future resource errors

# Processing Errors (56-63)
E_PROCESS_FAILED=56                 # General processing failure
E_PROCESS_TIMEOUT=57                # Processing timeout
E_PROCESS_MEMORY=58                 # Out of memory
E_PROCESS_CPU=59                    # CPU limit exceeded
E_PROCESS_DISK=60                   # Disk space exhausted
E_PROCESS_STREAM=61                 # Stream processing error
E_PROCESS_PARSE=62                  # Parse/decode error
E_PROCESS_RESERVED=63               # Reserved for future processing errors

# File System Errors (64-71)
E_FS_NOT_FOUND=64                   # File not found
E_FS_PERMISSION=65                  # File permission denied
E_FS_READONLY=66                    # File system read-only
E_FS_FULL=67                        # File system full
E_FS_LOCKED=68                      # File locked
E_FS_CORRUPT=69                     # File corrupted
E_FS_PATH=70                        # Invalid path
E_FS_RESERVED=71                    # Reserved for future FS errors

# Session/State Errors (72-79)
E_SESSION_EXPIRED=72                # Session expired
E_SESSION_INVALID=73                # Invalid session
E_SESSION_CONFLICT=74               # Session conflict
E_SESSION_LOST=75                   # Session lost
E_SESSION_LIMIT=76                  # Session limit exceeded
E_STATE_INVALID=77                  # Invalid state
E_STATE_TRANSITION=78               # Invalid state transition
E_STATE_RESERVED=79                 # Reserved for future state errors

# History/Persistence Errors (80-87)
E_HISTORY_NOT_FOUND=80              # History entry not found
E_HISTORY_CORRUPT=81                # History corrupted
E_HISTORY_FULL=82                   # History storage full
E_HISTORY_ENCRYPT=83                # History encryption error
E_HISTORY_DECRYPT=84                # History decryption error
E_HISTORY_CLEANUP=85                # History cleanup failed
E_HISTORY_WRITE=86                  # History write failed
E_HISTORY_RESERVED=87               # Reserved for future history errors

# Streaming Errors (88-95)
E_STREAM_DISCONNECT=88              # Stream disconnected
E_STREAM_TIMEOUT=89                 # Stream timeout
E_STREAM_FORMAT=90                  # Stream format error
E_STREAM_CHUNK=91                   # Stream chunk error
E_STREAM_BUFFER=92                  # Stream buffer overflow
E_STREAM_ENCODE=93                  # Stream encoding error
E_STREAM_DECODE=94                  # Stream decoding error
E_STREAM_RESERVED=95                # Reserved for future stream errors

# Model/AI Errors (96-103)
E_MODEL_NOT_FOUND=96                # Model not found
E_MODEL_UNAVAILABLE=97              # Model unavailable
E_MODEL_CONTEXT=98                  # Context window exceeded
E_MODEL_TOKEN=99                    # Token limit exceeded
E_MODEL_RESPONSE=100                # Invalid model response
E_MODEL_TIMEOUT=101                 # Model timeout
E_MODEL_QUOTA=102                   # Model quota exceeded
E_MODEL_RESERVED=103                # Reserved for future model errors

# Workspace Errors (104-111)
E_WORKSPACE_NOT_FOUND=104           # Workspace not found
E_WORKSPACE_EMPTY=105               # Workspace empty
E_WORKSPACE_LARGE=106               # Workspace too large
E_WORKSPACE_SCAN=107                # Workspace scan failed
E_WORKSPACE_INDEX=108               # Workspace index error
E_WORKSPACE_SYNC=109                # Workspace sync failed
E_WORKSPACE_CONFLICT=110            # Workspace conflict
E_WORKSPACE_RESERVED=111            # Reserved for future workspace errors

# Context Errors (112-119)
E_CONTEXT_NOT_FOUND=112             # Context not found
E_CONTEXT_EMPTY=113                 # Context empty
E_CONTEXT_LARGE=114                 # Context too large
E_CONTEXT_TRUNCATE=115              # Context truncation failed
E_CONTEXT_ENCODE=116                # Context encoding error
E_CONTEXT_DECODE=117                # Context decoding error
E_CONTEXT_LIMIT=118                 # Context limit exceeded
E_CONTEXT_RESERVED=119              # Reserved for future context errors

# Payload Errors (120-127)
E_PAYLOAD_INVALID=120               # Invalid payload
E_PAYLOAD_LARGE=121                 # Payload too large
E_PAYLOAD_FORMAT=122                # Payload format error
E_PAYLOAD_SCHEMA=123                # Payload schema error
E_PAYLOAD_ENCODE=124                # Payload encoding error
E_PAYLOAD_DECODE=125                # Payload decoding error
E_PAYLOAD_SIGN=126                  # Payload signing error
E_PAYLOAD_RESERVED=127              # Reserved for future payload errors

# Configuration Management Errors (128-135)
E_CONFIG_GET=128                    # Config get failed
E_CONFIG_SET=129                    # Config set failed
E_CONFIG_LIST=130                   # Config list failed
E_CONFIG_RESET=131                  # Config reset failed
E_CONFIG_EXPORT=132                 # Config export failed
E_CONFIG_IMPORT=133                 # Config import failed
E_CONFIG_VALIDATE=134               # Config validation failed
E_CONFIG_RESERVED=135               # Reserved for future config mgmt errors

# Interactive Mode Errors (136-143)
E_INTERACTIVE_EXIT=136              # Interactive mode exit
E_INTERACTIVE_ABORT=137             # Interactive mode abort
E_INTERACTIVE_TIMEOUT=138           # Interactive mode timeout
E_INTERACTIVE_INPUT=139             # Interactive input error
E_INTERACTIVE_OUTPUT=140            # Interactive output error
E_INTERACTIVE_DISPLAY=141           # Display error
E_INTERACTIVE_TERM=142              # Terminal error
E_INTERACTIVE_RESERVED=143          # Reserved for future interactive errors

# Observability/Metrics Errors (144-151)
E_METRICS_INIT=144                  # Metrics initialization failed
E_METRICS_EXPORT=145                # Metrics export failed
E_METRICS_FORMAT=146                # Metrics format error
E_METRICS_OVERFLOW=147              # Metrics buffer overflow
E_METRICS_STALE=148                 # Stale metrics data
E_METRICS_CONFIG=149                # Metrics config error
E_METRICS_PERM=150                  # Metrics permission error
E_METRICS_RESERVED=151              # Reserved for future metrics errors

# Logging Errors (152-159)
E_LOG_INIT=152                      # Logger initialization failed
E_LOG_WRITE=153                     # Log write failed
E_LOG_ROTATE=154                    # Log rotation failed
E_LOG_FORMAT=155                    # Log format error
E_LOG_LEVEL=156                     # Invalid log level
E_LOG_BUFFER=157                    # Log buffer overflow
E_LOG_DISK=158                      # Log disk full
E_LOG_RESERVED=159                  # Reserved for future logging errors

# Gemini Integration Errors (160-167)
E_GEMINI_INIT=160                   # Gemini init failed
E_GEMINI_AUTH=161                   # Gemini auth failed
E_GEMINI_REQUEST=162                # Gemini request failed
E_GEMINI_RESPONSE=163               # Gemini response error
E_GEMINI_FORMAT=164                 # Gemini format error
E_GEMINI_TIMEOUT=165                # Gemini timeout
E_GEMINI_QUOTA=166                  # Gemini quota exceeded
E_GEMINI_RESERVED=167               # Reserved for future Gemini errors

# OpenRouter Errors (168-175)
E_OPENROUTER_INIT=168               # OpenRouter init failed
E_OPENROUTER_AUTH=169               # OpenRouter auth failed
E_OPENROUTER_REQUEST=170            # OpenRouter request failed
E_OPENROUTER_RESPONSE=171           # OpenRouter response error
E_OPENROUTER_FORMAT=172             # OpenRouter format error
E_OPENROUTER_TIMEOUT=173            # OpenRouter timeout
E_OPENROUTER_QUOTA=174              # OpenRouter quota exceeded
E_OPENROUTER_RESERVED=175           # Reserved for future OpenRouter errors

# Environment Errors (176-183)
E_ENV_MISSING=176                   # Required env var missing
E_ENV_INVALID=177                   # Invalid env var value
E_ENV_CONFLICT=178                  # Conflicting env vars
E_ENV_PERMISSION=179                # Env permission error
E_ENV_LOAD=180                      # Env load failed
E_ENV_EXPORT=181                    # Env export failed
E_ENV_SANITIZE=182                  # Env sanitization failed
E_ENV_RESERVED=183                  # Reserved for future env errors

# Bootstrap Errors (184-191)
E_BOOTSTRAP_INIT=184                # Bootstrap init failed
E_BOOTSTRAP_LOAD=185                # Bootstrap load failed
E_BOOTSTRAP_MODULE=186              # Module load failed
E_BOOTSTRAP_ORDER=187               # Module order error
E_BOOTSTRAP_DEP=188                 # Dependency error
E_BOOTSTRAP_VERSION=189             # Version mismatch
E_BOOTSTRAP_CONFIG=190              # Bootstrap config error
E_BOOTSTRAP_RESERVED=191            # Reserved for future bootstrap errors

# Utility Errors (192-199)
E_UTIL_NOT_FOUND=192                # Utility not found
E_UTIL_EXEC=193                     # Utility execution failed
E_UTIL_TIMEOUT=194                  # Utility timeout
E_UTIL_OUTPUT=195                   # Utility output error
E_UTIL_INPUT=196                    # Utility input error
E_UTIL_FORMAT=197                   # Utility format error
E_UTIL_CHAIN=198                    # Utility chain error
E_UTIL_RESERVED=199                 # Reserved for future utility errors

# I/O Errors (200-207)
E_IO_READ=200                       # Read operation failed
E_IO_WRITE=201                      # Write operation failed
E_IO_OPEN=202                       # Open operation failed
E_IO_CLOSE=203                      # Close operation failed
E_IO_SEEK=204                       # Seek operation failed
E_IO_FLUSH=205                      # Flush operation failed
E_IO_SYNC=206                       # Sync operation failed
E_IO_RESERVED=207                   # Reserved for future I/O errors

# Security Errors (208-215)
E_SEC_VIOLATION=208                 # Security violation
E_SEC_INTEGRITY=209                 # Integrity check failed
E_SEC_SIGNATURE=210                 # Signature verification failed
E_SEC_ENCRYPT=211                   # Encryption failed
E_SEC_DECRYPT=212                   # Decryption failed
E_SEC_KEY=213                       # Key management error
E_SEC_CERT=214                      # Certificate error
E_SEC_RESERVED=215                  # Reserved for future security errors

# Internal/System Errors (216-223)
E_SYS_PANIC=216                     # System panic
E_SYS_FATAL=217                     # Fatal system error
E_SYS_CRITICAL=218                  # Critical system error
E_SYS_ERROR=219                     # General system error
E_SYS_WARNING=220                   # System warning
E_SYS_NOTICE=221                    # System notice
E_SYS_INFO=222                      # System info
E_SYS_DEBUG=223                     # System debug

# Reserved for Future Use (224-239)
E_RESERVED_224=224
E_RESERVED_225=225
E_RESERVED_226=226
E_RESERVED_227=227
E_RESERVED_228=228
E_RESERVED_229=229
E_RESERVED_230=230
E_RESERVED_231=231
E_RESERVED_232=232
E_RESERVED_233=233
E_RESERVED_234=234
E_RESERVED_235=235
E_RESERVED_236=236
E_RESERVED_237=237
E_RESERVED_238=238
E_RESERVED_239=239

# Custom/Extension Errors (240-254)
E_CUSTOM_240=240
E_CUSTOM_241=241
E_CUSTOM_242=242
E_CUSTOM_243=243
E_CUSTOM_244=244
E_CUSTOM_245=245
E_CUSTOM_246=246
E_CUSTOM_247=247
E_CUSTOM_248=248
E_CUSTOM_249=249
E_CUSTOM_250=250
E_CUSTOM_251=251
E_CUSTOM_252=252
E_CUSTOM_253=253
E_CUSTOM_254=254

# Special Case (255)
E_UNKNOWN=255                       # Unknown/unclassified error
