# Non-goals

What Tallow will not do. Saying no early keeps the project small enough to finish. This list changes by pull request, with a reason.

## Game

- **No multiplayer.** Single player only.
- **No close melee against giant beasts.** Combat is defence-led; first person is for the wall, the dawn hunt and the town.
- **No character survival.** No hunger, thirst or temperature for the player. Survival belongs to the town.
- **No diggable or voxel terrain.** Valleys are generated, but the ground is not editable.
- **No flat 2D map.** The command view is an angled 3D camera over the same 3D world.
- **No pay-to-win or monetisation inside the game.**

## Platforms and release

- **No mobile or console versions.** Desktop and web only.
- **No Steam release at first.** GitHub Pages and itch.io; Steam is a later decision.

## Technology

- **No C#.** Typed GDScript, because Godot's C# cannot export to the web.
- **No custom engine.**
- **No second copy of the game rules.** Python analyses telemetry; it never re-implements the simulation.
- **No unit tests for visuals or scenes.** We playtest them instead.
- **No chasing coverage numbers** for their own sake.

## Project

- **No outside code contributions for now.** Issues and feedback are welcome.
