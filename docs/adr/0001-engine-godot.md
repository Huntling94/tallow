# ADR-0001: Use Godot 4 with typed GDScript

- **Status:** Accepted (2026-11-03)
- **Date:** 2026-11-03
- **Related:** [ADR-0002](0002-sim-render-separation.md)

## Context

Tallow is a fully 3D strategy game with a command view and a first-person mode, built by a very small team working with Claude Code. The engine choice shapes almost everything else. What matters most:

- **AI-readable project files.** Claude must be able to read, write, diff and review scenes and scripts, not only code.
- **Headless runs.** The simulation must run without a window in CI, thousands of seasons at a time.
- **Web build.** A playable build in the browser is the easiest way for people to try the game.
- **No licence risk or fees.**
- **A visual editor**, for laying out 3D scenes, and a manageable learning curve.

## Options

### Option 1: Godot 4 (typed GDScript)

- **For:** scenes, resources and scripts are plain text, so they can be read, diffed and reviewed. Free and open source (MIT), no fees. Small install. Headless mode for CI. Exports to the web.
- **Against:** a smaller 3D ecosystem and asset library. 3D visuals below Unreal. Web builds use the simpler Compatibility renderer, so the browser version looks plainer than desktop.

### Option 2: Unity

- **For:** an industry standard with a huge asset store and many tutorials. C#.
- **Against:** verbose scene files that are hard to review. Trust in its licensing was damaged by the 2023 runtime-fee announcement, since withdrawn. CI needs licence activation. Heavier install.

### Option 3: Unreal Engine 5

- **For:** the best visuals (Lumen lighting, Nanite geometry).
- **Against:** Blueprints are binary, so AI cannot read or review them. C++. A very large install. No web export. A royalty on revenue above US$1 million.

### Option 4: Bevy (Rust)

- **For:** code-only, highly testable and AI-friendly.
- **Against:** no visual editor. A young engine. Steep for a first game.

### Option 5: three.js or Babylon.js

- **For:** web-native. TypeScript. Strong testing.
- **Against:** we would build the engine ourselves: physics, animation, UI and tools.

## Decision

Use **Godot 4, standard build, with typed GDScript**. It is the only option that meets all of: AI-readable project files, headless runs, a web build, a visual editor and no licence risk.

We use typed GDScript rather than C# because Godot's C# builds cannot export to the web.

## Consequences

- **Easier:** Claude can review every scene and script in a PR. CI can run the simulation headless. Builds deploy to GitHub Pages. No licence fees or activation.
- **Harder:** fewer ready-made 3D assets; more custom work for the beasts. The web build will look plainer than desktop, so the visual target is judged on the desktop build and the web build is the easy-access version.
- **What we now have to do:**
  - Pin the exact Godot version in `game/project.godot`, the CI workflows and the contributing guide when the Godot project lands (M0, step 6). Upgrades within 4.x are made by PR; a move to Godot 5 needs a new ADR.
  - Require static typing in GDScript (see the coding standards) and turn on Godot's typing warnings.
  - Test the web build from M0 so its limits are known early.
- **Revisit if:** the web build cannot run the simulation fast enough, or the 3D target proves out of reach with Godot's renderer.
