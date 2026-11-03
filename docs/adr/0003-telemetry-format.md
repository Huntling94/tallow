# ADR-0003: Telemetry as versioned JSON Lines, converted to Parquet for analysis

- **Status:** Accepted (2026-11-03)
- **Date:** 2026-11-03
- **Related:** [ADR-0002](0002-sim-render-separation.md), [architecture overview](../architecture/overview.md)

## Context

The simulation emits events (herd arrives, route chosen, beast killed, harvest recovered, trade made, rare event occurs). Python reads them to fit and calibrate models, check balance targets and produce reports. The format needs to:

- Be easy to write from GDScript, with no extra dependencies.
- Be readable by people and by Claude when debugging.
- Survive change: new events and fields arrive every milestone.
- Load fast in Python for analysis across thousands of runs.
- Be deterministic, so golden-seed tests can compare outputs exactly.

## Options

### Option 1: JSON Lines written by Godot, converted to Parquet in Python

- **For:** one JSON object per line is simple to write from GDScript and to append to. Readable and diff-friendly. Streams well. Parquet gives Python fast, typed, compressed columns.
- **Against:** JSON files are larger and slower to parse; a conversion step is needed. Types must be enforced by a schema rather than the format.

### Option 2: CSV

- **For:** simplest possible; opens anywhere.
- **Against:** no nesting, weak types, one file per event type, fragile when columns change.

### Option 3: SQLite written by Godot

- **For:** typed, queryable, one file per run.
- **Against:** needs a GDExtension in Godot; not available in the web build; binary files are hard to diff or review.

### Option 4: Parquet written directly by Godot

- **For:** no conversion step.
- **Against:** no Parquet writer for GDScript; would need a GDExtension.

## Decision

**Option 1.** The simulation writes **JSON Lines** (`.jsonl`), one file per run, with a schema version on every record. Python validates each file against the schema, then converts it to **Parquet** for analysis.

## Format

- **First line: a run header.** `type: "run_start"`, `schema_version`, `run_id`, `seed`, game version, and the run's settings (valley, herd personality, modifier, bot strategy).
- **Then one event per line**, each with: `schema_version`, `run_id`, `season`, `tick`, `seq` (a counter that orders events within a tick), `type`, and the event's own fields.
- **Last line: a run summary** (`type: "run_end"`): outcome, score and season count. A file without one is an incomplete run.
- **No wall-clock times in events.** Times are the simulation's own season and tick, so the same seed gives byte-identical files. When and where a run happened goes in a separate manifest next to the file, which golden tests ignore.
- **Versioning:** `schema_version` is a whole number. Adding an optional field does not change it; renaming, removing or changing the meaning of a field does, and the change is recorded in the data dictionary.
- **Location:** headless runs write to `telemetry/` (git-ignored). Small sample files for tests live in `analysis/fixtures/`.

## Consequences

- **Easier:** GDScript writes telemetry with built-in JSON support; files are readable in any editor; golden tests compare files directly; Python gets fast typed tables.
- **Harder:** a schema and a data dictionary must be kept in step with the code; large bot runs produce large files before conversion.
- **What we now have to do:**
  - A telemetry writer outside `game/src/sim/` that takes events from the simulation and writes JSON Lines (M0, step 8).
  - A telemetry data dictionary in `docs/architecture/telemetry.md`, with every event and field, its type and the version it arrived in (M1).
  - A Python loader that validates files against the schema, rejects unknown versions loudly, and writes Parquet.
  - Compress large bot-run files (gzip) if size becomes a problem.
- **Revisit if:** writing JSON becomes a measurable cost in bot runs, or files grow too large to handle.
