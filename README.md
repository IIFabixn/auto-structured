# Auto Structured — WFC Redesign Roadmap

This living roadmap captures the multi-phase plan for overhauling the Wave Function Collapse (WFC) system that powers Auto Structured. It translates the recent architectural proposal into actionable milestones so we can evolve the solver without destabilizing the editor experience.

---

## 🎯 Objectives

1. **Performance headroom**: Replace per-cell dictionaries with bitset-backed catalogs so large grids (≥256³) solve without memory spikes.
2. **Composable constraints**: Decouple tile requirements, region rules, and future gameplay logic via a plug-in constraint API.
3. **Strategy freedom**: Allow custom heuristics, multi-pass layouts, and streaming/async solving without forking the solver core.
4. **Robust backtracking**: Switch from full snapshots to diff logs so deeper search (depth ≥64) becomes affordable.
5. **Tooling & UX**: Deliver better debug overlays, deterministic seeds, and resumable solves for artist workflows.

---

## 🧱 Target Architecture (High Level)

| Layer | Description | Key Deliverables |
| --- | --- | --- |
| **Catalog** | Immutable data derived from module libraries (tiles, variants, sockets). | `TileCatalog`, `VariantCatalog`, `CompatibilityAtlas` resources with precomputed bit masks per direction. |
| **State** | Runtime grid/cell storage using packed bit arrays and entropy caches. | `CellState`, `GridChunk`, chunk-aware entropy heap, serialization helpers. |
| **Constraints** | Modular constraint interfaces (local, neighborhood, global). | Base classes, refactored tile requirements, region tracker as `GlobalConstraint`, serialization + snapshot API. |
| **Strategies** | Solving policies that can prepare grids, pick cells, adjust weights, or inject new constraints. | Extended `WfcSolveStrategy` API, reference strategies (Entropy, Layout-First, Guided). |
| **Runtime** | Async-friendly solver loop, diff-based backtracking, progress reporting. | Worker-thread execution, progress channel, chunk streaming hooks. |

---

## 🗺️ Phase Plan

### Phase 0 — Baseline Audit *(complete)*
- Inventory current WFC files, requirements, strategies, and region logic.
- Document gaps (performance, coupling, limited hooks).

### Phase 1 — Catalog & Bitsets
- Build generator that produces a `TileCatalog.res` per module library (variants, sockets, compatibility masks).
- Swap `Array[Dictionary]` variants for packed bitsets, but keep existing solver loop to ensure parity.
- Ship hidden behind a project setting (`wfc.use_bitsets`).

### Phase 2 — Constraint Interfaces
- Introduce `LocalConstraint`, `NeighborhoodConstraint`, and `GlobalConstraint` base classes.
- Port tile requirements + boundary enforcement to the new interfaces.
- Keep solver integration thin (collect masks from constraints, intersect with cell state).

### Phase 3 — Solver Core Rewrite
- Implement the chunk-aware grid, entropy heap using cached values, and propagation via mask unions.
- Replace old snapshots with diff logs per checkpoint, including constraint deltas.
- Maintain feature flag to revert to legacy solver if issues arise.

### Phase 4 — Strategy Expansion & Async
- Extend `WfcSolveStrategy` with hooks (`before_collapse`, `after_propagation`, `inject_constraints`).
- Add background worker solving with progress events + cancellation.
- Build at least two showcase strategies: Layout-first (zone carving) and Guided entropy (anchor-aware).

### Phase 5 — Streaming, Tooling & QA
- Implement chunk serialization/resume, deterministic seeds, and debug overlays (entropy heatmaps, constraint reasons).
- Author regression tests + benchmark scenes covering small, medium, and massive grids.
- Formalize migration guide; retire legacy solver flag once parity proven.

---

## 📐 Acceptance Criteria Per Phase

| Phase | Key Tests | Success Metrics |
| --- | --- | --- |
| 1 | Catalog generator unit tests; bitset solver parity scenes. | ≤5% memory overhead vs legacy, identical outputs on seed corpus. |
| 2 | Constraint plug-in samples + editor UI integration. | New requirement type ships without solver changes. |
| 3 | Stress scenes 128³–256³; backtracking depth 64. | 2× speedup vs legacy on target scenes, backtrack memory ≤20% legacy. |
| 4 | Interactive solve demo, background worker cancellation. | UI remains responsive; strategies selectable per library. |
| 5 | Automated regression suite + visual debugger. | 0 unresolved parity bugs for four consecutive weekly builds. |

---

## 🔧 Supporting Infrastructure

- **Testing**: Godot unit tests plus Python benchmarks for catalog generation.
- **Telemetry**: Optional solve traces written to JSON for offline analysis.
- **Docs**: Developer guide explaining constraint authoring, strategy lifecycle, and chunk serialization.

---

## 🚀 Next Steps

1. Prototype the catalog generator (Phase 1) in a separate branch.
2. Define bitset utilities (`PackedBitArray` helpers, mask unions, diff logs).
3. Draft constraint base interfaces and migrate one requirement as a spike.

Keep this roadmap updated as milestones land. When in doubt, open an issue referencing the relevant phase to maintain traceability.
