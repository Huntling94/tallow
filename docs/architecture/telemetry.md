# Telemetry data dictionary

Every record the game writes to a telemetry file, with its fields, their types and the version each arrived in. This is the reference; specs only describe their changes. The file format itself (JSON Lines, one run per file, the header and summary, versioning rules) is set by [ADR-0003](../adr/0003-telemetry-format.md).

**Versions.** `schema_version` is a whole number on every record, currently **1**. Adding a record type or an optional field keeps the version; renaming, removing or changing the meaning of a field raises it and is recorded here. The "Since" column gives the spec that added each field.

**Types.** *int* is a whole number, *float* a decimal number, *string* text, *list* a JSON array and *object* a JSON object. A field marked *id* is a stable string from the game data, such as a route id from `game/data/valleys/`.

## Common event fields

Every record between the header and the summary has these.

| Field | Type | Meaning | Since |
|---|---|---|---|
| `type` | string | The record type, one of the event types below | 0027 |
| `schema_version` | int | The telemetry schema version | 0027 |
| `run_id` | string | The run this event belongs to; matches the header | 0027 |
| `season` | int | Season number, from 1 | 0027 |
| `tick` | int | Simulation tick within the season, from 0 | 0027 |
| `seq` | int | Order of events within a tick, from 0. (`season`, `tick`, `seq`) strictly increases through the file | 0027 |

## `run_start` (first line)

| Field | Type | Meaning | Since |
|---|---|---|---|
| `type` | string | `"run_start"` | 0027 |
| `schema_version` | int | The telemetry schema version | 0027 |
| `rules_version` | string | 16 hex characters identifying the simulation code and game data (see ADR-0003) | 0027 |
| `run_id` | string | 16 hex characters derived from the rules version, seed and settings | 0027 |
| `seed` | int | The run seed | 0027 |
| `settings` | object | The run's settings, below | 0027 |
| `settings.valley` | id | The valley file in `game/data/valleys/` | 0027 |
| `settings.herd_personality` | id | The herd file in `game/data/herds/`, which holds the true route-choice weights | 0027 |
| `settings.modifier` | string or null | Run modifier; null until modifiers exist | 0027 |
| `settings.bot_strategy` | string | The bot that played, or `"none"` | 0027 |
| `settings.seasons` | int | Seasons requested | 0027 |

## `herd_arrived`

A herd enters the valley. One per season, first in the season.

| Field | Type | Meaning | Since |
|---|---|---|---|
| `herd_size` | int | Beasts in the herd | 0027 |
| `bands` | int | How many bands the herd split into; one `route_chosen` follows for each | 0037 |

## `route_options`

The routes on offer this season, with the features the choice model uses and the odds it gave. One per season, after `herd_arrived`. Every band in the season faces these same options.

| Field | Type | Meaning | Since |
|---|---|---|---|
| `routes` | list of object | One entry per route, in the valley file's route order | 0037 |
| `routes[].route` | id | The route | 0037 |
| `routes[].length_m` | int | Total length in metres | 0037 |
| `routes[].rough_m` | int | Rough metres: the sum over segments of length × roughness, rounded per segment | 0037 |
| `routes[].threat` | int | Total threat from defences on the route; 0 until defences exist | 0037 |
| `routes[].utility` | float | The route's utility under the herd's true weights, to 6 decimal places. A check for the route fit, not an input to it | 0037 |
| `routes[].p_ppm` | int | The route's chance in parts per million; the entries sum to exactly 1,000,000 | 0037 |

## `route_chosen`

One band picks its route. One per band, after `route_options`.

| Field | Type | Meaning | Since |
|---|---|---|---|
| `band` | int | Band number within the season, from 1 | 0037 |
| `beasts` | int | Beasts in the band; the season's bands add up to `herd_size` | 0037 |
| `route` | id | The route chosen, one of the season's `route_options` | 0037 |

## `season_ended`

The season is over. One per season, last in the season. No fields of its own.

## `run_end` (last line)

A file without one is an incomplete run.

| Field | Type | Meaning | Since |
|---|---|---|---|
| `type` | string | `"run_end"` | 0027 |
| `schema_version` | int | The telemetry schema version | 0027 |
| `run_id` | string | Matches the header | 0027 |
| `outcome` | string | `"completed"` for now | 0027 |
| `score` | int | 0 for now | 0027 |
| `seasons` | int | Seasons played | 0027 |
