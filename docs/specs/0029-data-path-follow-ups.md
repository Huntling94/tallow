# Spec 0029: Data-path follow-ups before M1 builds on it

- **Issue:** #29
- **Status:** Approved (2026-11-05)
- **Pillar:** Foundations
- **Milestone:** M1

## Problem and why it matters

The review of #28 found gaps in the data path that M1 is about to build on. The simulation creates its own random streams, so every new M1 system would copy a pattern the coding standards forbid. The loader and `check_run` print raw tracebacks for some bad files instead of a clear error. The rules version can shrink silently if a folder moves, changes when a README is edited, and does not notice a file moving between folders. Fixing these now is cheap; fixing them after five systems copy them is not.

## Scope

- **Streams are passed in.** `SeasonRun.run` takes a `RandomStreams` instead of a seed. The headless run creates the streams from the run seed and hands them over.
- **Rules version fixes.** `RulesVersion` fails loudly on a folder it cannot open, ignores `.md` files, and hashes each file's full `res://` path. The headless run refuses to write a file when the rules version cannot be computed.
- **Loader errors.** The loader raises `TelemetryError` for a `season`, `tick` or `seq` that is not a whole number, and for a file that is not valid UTF-8. A file cut off during its header line says so instead of "file is empty".
- **One test renamed.** `test_a_loaded_run_cannot_be_changed` is renamed to say what it checks: the events are a tuple.

## Out of scope

- Parquet conversion. It moves to its own issue (#34) and PR: nothing needs it until the bots produce thousands of runs (M1 build step 6), and it brings a new dependency and a column layout to decide.
- Freezing the loaded records themselves (deep immutability). Renaming the test is enough for now.
- Any change to the telemetry format or schema version.

## Acceptance criteria

- **AC1:** Given a `RandomStreams` for seed 42, when `SeasonRun.run` is called with it, then the events match a run given a fresh `RandomStreams` for seed 42, and differ from one for seed 7. `SeasonRun` no longer calls `RandomStreams.new`.
- **AC2:** Given seed 42, when the headless runner runs, then the herd sizes are the same as before this change, and two runs with the same seed still give byte-identical files.
- **AC3:** Given a folder list where one folder does not exist, when the rules version is computed, then it returns an empty string and reports an error naming the folder, and the headless run returns an error without writing a file.
- **AC4:** Given the default rule folders, then both are found and the rules version is 16 hex characters.
- **AC5:** Given a rules folder, when only a `.md` file in it changes, then the rules version does not change.
- **AC6:** Given two rules folders, when a file moves from one to the other with the same name and contents, then the rules version changes.
- **AC7:** Given an event whose `season`, `tick` or `seq` is a string, a decimal or a boolean, when the file is loaded, then the loader raises `TelemetryError` naming the line and field, and `check_run` exits 1 with that message and no traceback.
- **AC8:** Given a file containing bytes that are not valid UTF-8, when it is loaded, then the loader raises `TelemetryError` naming the file, and `check_run` exits 1 with no traceback.
- **AC9:** Given a file whose only content is a header line cut off partway, when it is loaded, then the error says the run was cut off before its header was complete.

## Verification

| Criterion | How it is verified |
|---|---|
| AC1 | gdUnit4 test on `SeasonRun`; the boundary test plus a test that `season_run.gd` has no `RandomStreams.new` |
| AC2 | Existing herd-size tests keep their expected values; existing byte-identical test |
| AC3 | gdUnit4 tests on `RulesVersion` and `HeadlessRun` with a missing folder |
| AC4 | gdUnit4 test on the default folders |
| AC5, AC6 | gdUnit4 tests over temporary folders |
| AC7, AC8, AC9 | pytest on the loader and `check_run` |

## Telemetry

None. The format and schema version are unchanged. The rules version of every run changes once, because the hash now covers full paths and skips `.md` files.

## Design notes

- **Failing loudly in GDScript:** GDScript has no exceptions. `RulesVersion.compute` calls `push_error` with the folder name and returns `""`. `HeadlessRun.run` treats `""` as `ERR_FILE_NOT_FOUND`, so the runner exits 1 and CI fails.
- **Paths in the hash:** each file contributes its full path (for example `res://src/sim/season_run.gd`), then its contents with line endings normalised to LF. Files are still taken in sorted order within each folder, folders in the order given.
- **Ignored files:** `.uid`, `.import` and now `.md`. Docs inside rule folders (such as `game/src/sim/README.md`) no longer change the rules version.
- **Whole numbers:** in Python, `bool` is a subclass of `int`, so `True` is ruled out explicitly, as the loader already does for `schema_version`.
- **UTF-8:** the loader reads bytes and decodes them itself, so it can name the file in the error.

## Open questions

- None blocking.
