#!/usr/bin/env bash
# Sync llm_wiki workflows to Antigravity global workflows

GLOBAL_DIR="$HOME/.gemini/antigravity/global_workflows"

echo "🔄 Syncing LLM-WIKI workflows to global directory: $GLOBAL_DIR"

mkdir -p "$GLOBAL_DIR"
cp -f .agents/workflows/ingest-*.md "$GLOBAL_DIR/"
cp -f .agents/workflows/query-*.md "$GLOBAL_DIR/"
cp -f .agents/workflows/lint-*.md "$GLOBAL_DIR/"

echo "✅ Sync complete! Available workflows:"
ls -1 "$GLOBAL_DIR"/*.md 2>/dev/null | xargs -I{} basename {}
echo ""
echo "Please type '/' in your Antigravity IDE to verify."
