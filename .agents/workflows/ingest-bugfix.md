# Ingest Bugfix Experience

This workflow extracts error/bugfix experience from a raw log or user description, and creates a structured knowledge entry in the Wiki.

1. **Read Raw Data**: 
   - Parse the target file in the `raw/` directory (e.g. `raw/error_log.txt`).
2. **Analyze the Bug**: 
   - Extract the environment setup (e.g., CANN version, framework).
   - Extract the core error message or stack trace.
   - Identify the root cause and the proposed solution (Workaround or Fix).
3. **Format via Template**: 
   - Use `templates/bugfix_template.md` to format the knowledge clearly. 
   - Ensure you fill in the YAML frontmatter.
4. **Save to Wiki**: 
   - Save the formatted document to a relevant path, such as `wiki/02_precision/` or `wiki/01_operators/` with a descriptive name (e.g., `wiki/02_precision/attn_fp16_overflow.md`).
5. **Update Index & Changelog**: 
   - Insert a `[[WikiLink]]` to the new page in exactly the right category within `index.md`.
   - Prepend a log entry in `changelog.md` to record what was just ingested.
