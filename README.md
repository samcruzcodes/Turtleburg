# Turtleburg

A small top-down pixel-art game about a seaside town, the sea turtles that have stopped coming to its
yearly ceremony, and the small, practical things that bring them back: fixing leaky fixtures with
water-saving upgrades and cleaning up pollution. Made with Godot 3.6 and Dialogic 1.3.

## Controls

| Action | Keys |
| --- | --- |
| Move | WASD or arrow keys |
| Jog | hold Shift while moving |
| Talk / use what is in front of you | Space, Enter or E |
| Open or close the quest journal | Q |
| Open or close the town map | M (Esc, Space, Enter or E also close it) |
| Pause menu | Esc |
| Open a building's door | walk up and press Space / Enter / E, or left-click the entrance |

Building entrances show a small name plate when you are close to them or point at them with the mouse.
The map shows a green pin on every place an active quest step points to.

## Running from source

1. Install [Godot 3.6.x](https://godotengine.org/download/archive/) (the standard build, not Mono).
2. Open `project.godot` in Godot and press Play, or run `godot --path .`.

## Exporting

`export_presets.cfg` defines the web, Windows and macOS presets. Install the matching Godot 3.6.x
export templates and run, for example:

```
godot --path . --export "Turtleburg macOS" build/Turtleburg-macos.zip
```

## Tests

`tests/run_tests.sh <path-to-Godot> <test>` runs the headless regression scenarios in
`tests/tb_tests.gd` against a throw-away profile, so real saves are never touched. For example
`npc_anim` checks that walking NPCs face the way they move; run it at different frame rates with
`TB_GODOT_ARGS="--fixed-fps 30"`.

## License

MIT, see [LICENSE](LICENSE).
