# ADR-0004: Document the architecture with the C4 model in Mermaid

- **Status:** Proposed
- **Date:** 2026-11-03
- **Related:** [architecture overview](../architecture/overview.md)

## Context

The architecture needs to be understood by people arriving cold: contributors, reviewers, and AI agents starting a fresh session. The documentation has to:

- Explain the system at more than one level of detail, from "what is this?" to "what are the parts inside the game?".
- Live in the repository, so it is reviewed and versioned with the code.
- Be readable and editable as text, so Claude can update it and diffs show what changed.
- Render on GitHub with no extra tooling.
- Stay cheap enough to keep accurate as the system changes.

## Options

### Option 1: C4 model, drawn as Mermaid flowcharts in Markdown

- **For:** C4 gives a small, widely used set of views (context, containers, components, code), each zooming in on the one above, with a simple notation. Mermaid is plain text and renders natively on GitHub. Supplementary views (dynamic, state, deployment) fit alongside.
- **Against:** each diagram is drawn by hand, so the same element can drift between views. Flowcharts need a consistent styling convention to read as C4.

### Option 2: C4 using Mermaid's dedicated C4 syntax

- **For:** C4 element types built in.
- **Against:** still marked experimental, with weak automatic layout that overlaps boxes on larger diagrams.

### Option 3: Structurizr DSL (one model, many generated views)

- **For:** C4's reference tooling. Define each element once and generate every view from it, so views cannot drift.
- **Against:** needs a separate tool or service to render; GitHub does not show it inline. More to learn and maintain for a small project.

### Option 4: arc42 template

- **For:** a complete template for architecture documentation (goals, constraints, building blocks, runtime, deployment, decisions, risks).
- **Against:** much of it is already covered here (vision, ADRs, risk register). Adopting it whole adds sections we would not keep current.

### Option 5: UML or free-form diagrams

- **For:** UML is precise and well known; free-form is fast.
- **Against:** full UML is heavy for this purpose. Free-form diagrams have no shared notation, so readers must guess what boxes and arrows mean.

## Decision

**Option 1.** Document the architecture with **C4 levels 1 to 3**, plus **dynamic, state and deployment views** where they explain something the structure cannot, all drawn as **Mermaid flowcharts and diagrams in Markdown**. Level 4 (code) is not drawn; the code is its own source of truth.

## Conventions

- Every diagram has a title, says what it **shows** and what it **leaves out**, and stays at one level of detail.
- Every box gives its name, its type and technology in square brackets, and a one-line responsibility.
- Every arrow is labelled with what flows.
- External systems are dashed; planned elements are marked *planned*.
- One consistent colour scheme for people, systems, containers and external systems.
- A PR that changes a container, component or dependency updates the matching diagram in the same PR.

## Consequences

- **Easier:** anyone can find the right level of detail quickly; diagrams are reviewed in PRs like code; Claude can read and update them.
- **Harder:** keeping element names consistent across hand-drawn views takes care; the reviewer checks it.
- **What we now have to do:** keep `docs/architecture/overview.md` current; add a detailed page per container (for example `simulation.md`, `telemetry.md`) as each container grows.
- **Revisit if:** the views drift out of step with each other often enough that a single model (Structurizr) is worth its tooling cost.
