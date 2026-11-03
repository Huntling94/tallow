# Architecture decision records

An ADR records one significant or hard-to-reverse decision: the context, the options considered, what we chose and what follows from it. They explain why the project is the way it is.

## How they work

- **When to write one:** a choice that shapes the architecture, is costly to undo, or that someone will later ask "why did we do it this way?" about. Draft with `/adr` during the plan (gate 2).
- **Numbering:** four digits, in order, never reused. File name `NNNN-short-name.md`, from [`0000-template.md`](0000-template.md).
- **Status:** Proposed → Accepted (by the maintainer, with a date) → optionally Superseded or Deprecated.
- **Accepted ADRs are not edited.** To change a decision, write a new ADR and mark the old one "Superseded by ADR-NNNN". Fixing a broken link or a typo is the only exception.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-engine-godot.md) | Use Godot 4 with typed GDScript | Accepted |
| [0002](0002-sim-render-separation.md) | Keep one deterministic simulation, separate from rendering | Proposed |
| [0003](0003-telemetry-format.md) | Telemetry as versioned JSON Lines, converted to Parquet for analysis | Proposed |
| [0004](0004-architecture-documentation-c4.md) | Document the architecture with the C4 model in Mermaid | Proposed |
