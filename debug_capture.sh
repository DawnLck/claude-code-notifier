#!/usr/bin/env bash
INPUT=$(cat)
echo "TIMESTAMP: $(date)" >> /Users/echo/Desktop/claude-code-notifier/debug_input.json
echo "$INPUT" >> /Users/echo/Desktop/claude-code-notifier/debug_input.json
echo "$INPUT" | bash /Users/echo/Desktop/claude-code-notifier/claude-code-notify.sh
