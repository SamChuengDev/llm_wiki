# Ingest Precision Alignment

This workflow guides the agent to document precision alignment issues like NaN occurrences, overflows, or output deviations compared to a baseline (e.g., GPU).

1. **Read Alignment Data**: 
   - Parse the relevant log, debug trace, or forum discussion from the `raw/` folder.
2. **Isolate the Issue**: 
   - Identify the specific layer/operator causing the deviation (e.g., `RMSNorm`, Attention block).
   - Identify the precision format in use (FP16, BF16, FP32).
3. **Extract Debug Logic & Resolution**: 
   - Document the methodology used to trace the bug (e.g., hook-based tensor dumping, precision comparison tools).
   - Detail the fix (e.g., enforcing FP32 for certain accumulations, adding epsilons, manually casting weights).
4. **Draft Document**: 
   - Base the formatting on `templates/precision_template.md`. 
   - Ensure the workaround/solution is presented with clear before/after code blocks if applicable.
5. **Save to Wiki**: 
   - Save to the `wiki/02_precision/` directory with a standardized naming convention (e.g., `wiki/02_precision/rmsnorm_bf16_nan.md`).
6. **Update Index & Changelog**: 
   - Insert a `[[WikiLink]]` to the new guide in `index.md`.
   - Prepend a log entry in `changelog.md`.
