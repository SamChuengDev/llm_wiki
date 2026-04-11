# Ingest Tuning Experience

This workflow directs the agent to extract performance tuning insights from raw profiling data, profiling summaries, or optimization discussions.

1. **Analyze Target Data**: 
   - Read the raw optimization notes or profiling summary in `raw/`.
2. **Extract Key Metrics**: 
   - Identify the baseline performance (e.g., token throughput, iteration time).
   - Identify the optimized performance.
   - Pinpoint the bottleneck (e.g., communication overhead, memory bound, compute bound).
3. **Extract Solutions**: 
   - Document the explicit optimization steps taken (e.g., specific environment variables adjusted like `HCCL_XXX`, operator fusion applied, memory reuse activated).
4. **Draft Document**: 
   - Base your formatting on `templates/tuning_template.md`.
   - Provide a clear before/after comparison and actionable steps.
5. **Save to Wiki**: 
   - Save the markdown file in `wiki/03_tuning/` with a coherent name (e.g., `wiki/03_tuning/hccl_async_overlap.md`).
6. **Update Index & Changelog**: 
   - Add a `[[WikiLink]]` to the new guide into the `03_tuning` section of `index.md`.
   - Add a log entry in `changelog.md`.
