# Risk register

Reviewed at every milestone start and review. Likelihood and impact are rated low, medium or high. The owner is the maintainer unless noted.

| # | Risk | Likelihood | Impact | Mitigation | Review at |
|---|---|---|---|---|---|
| R1 | **Scope outgrows a small team.** Two modes (command view and first person) roughly double the interface work. | High | High | Build in stages, simulation first and first person late (M5, M6). Keep the slice's town thin. Non-goals list. Each milestone answers one question before the next starts. | Every milestone |
| R2 | **Process outruns the game.** Foundations and governance eat the time meant for gameplay. Happened on M0 day one; see the [M0 review](m0-review.md). | High | High | M0 is timeboxed to one to two weeks part-time. Small changes may combine gates 1 and 2, and the maintainer may waive them for non-simulation work. One process change per milestone review, not more. | Every milestone |
| R3 | **The core loop is not fun.** Committing defences under uncertainty may feel like guesswork rather than skill. | Medium | High | M1 tests it headless with bots before any 3D work; M2 tests it by playing. Kill or change the design at either point. | M1, M2 |
| R4 | **Custom beast models and animation.** Colossal beasts need custom low-poly models; the main art risk. | High | Medium | Grey boxes until M5. Simple, readable silhouettes over detail. Decide the AI-generated art question by ADR before art lands. | M4 |
| R5 | **The statistics overtake the fun.** Players see spreadsheets instead of tension. | Medium | Medium | Players feel the models through tension and prices; the maths lives in the almanac and the repo. Playtests against pillar 2 (Read the odds) check it. | M3, M6 |
| R6 | **A dominant strategy or an economy exploit.** For example "store everything and sell at the spike". | Medium | Medium | Design contracts as CI tests from M1; bots search for dominant strategies; storage costs are designed in. | M1, M3 |
| R7 | **Late game flattens.** Forecasts become near-certain once the survey office is upgraded. | Medium | Medium | Uncertainty must rise faster than forecasting improves: new species, weather, herds that learn which routes are deadly. | M7 |
| R8 | **The web build disappoints.** The web uses Godot's simpler Compatibility renderer, so it looks plainer than desktop. | High | Medium | Judge the visual target on the desktop build; treat the web build as the easy-access version. Test the web build every milestone from M0. | M0, M5 |
| R9 | **Simulation is not deterministic across platforms.** Floating-point or ordering differences break seeds and golden tests. | Medium | High | ADR-0002 rules; golden-seed tests in CI; integer or fixed-step maths where order matters. | M1 |
| R10 | **AI-written code hides mistakes.** Plausible but wrong code or models get through. | Medium | High | Tests first for simulation code, an independent reviewer with fresh context, ground-truth recovery tests for models, the maintainer plays every build. Mistakes are written up in the devlog. | Every milestone |
| R11 | **Asset licences are unclear.** A third-party asset without a clear licence ends up in a release. | Low | High | CC0 packs where possible; every asset in `CREDITS.md`; a CI check for unlisted assets before the first art lands. | M2 |
| R12 | **Public text drifts off topic.** | Low | Medium | Public-language guard in pre-commit, Claude hooks and CI. | M0 |
| R13 | **Harvest becomes admin.** Managing townspeople's crews turns into busywork. | Medium | Medium | Few, big crew decisions (how many crews, which carcasses first), never individual worker micromanagement. Test in M3 by playing. | M3 |
| R14 | **Rare events feel unfair.** One unlucky event ends a well-played run. | Medium | High | Odds always shown; preparation available at a cost; a design contract that a well-prepared town survives any single rare event, tested over many seeds. | M1, M4 |
