# Ingest Tuning Experience

This workflow directs the agent to extract performance tuning insights from raw profiling data, profiling summaries, or optimization discussions.

1. **Context Extraction (Submodule Aware)**: 
   - Formulate the tuning experience based on recent conversation history (the iterative optimization steps just executed by the Agent in the main workspace) OR a profiling summary in `raw/`.
   - Guarantee you write the resulting docs into the correct `llm_wiki` submodule path.
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
