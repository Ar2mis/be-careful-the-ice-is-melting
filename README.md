# Be careful! The ice is melting!

Guide a melting ice cube to the freezer. Place up to four arrows on the ice, then press **Start run**. The cube turns when it lands on an arrow. It starts with 7.68 seconds of ice. Planning and pausing stop the melt clock. Running out of ice leaves a puddle.

[Play in your browser](https://melt-shift-first-journey.spry-mochi-0970.chatgpt.site/)

Select a direction with WASD or the on-screen controls. Click a tile to place an arrow, right-click to erase, press Space to run or pause, and press R to edit the route. Step advances the cube one tile. The tutorial has two routes to the freezer.

## Run or build

Import `game/project.godot` into Godot 4.7.2 and press F5. To run the rule checks and export the browser game, install the matching Web export templates and run:

```sh
python3 scripts/build.py
python3 scripts/serve.py
```

Open the local address printed by the server. The standard HTML game ZIP for itch.io is written to `artifacts/melt-shift-web.zip`. The hosted build in `dist/` uses a compressed copy of the same engine.

## Credits

Built with Godot and GDScript with AI assistance. The artwork is drawn by the game. The font is a renamed subset of Noto Sans SC distributed under the [SIL Open Font License](game/assets/fonts/OFL.txt). The route planning mechanic was inspired by Kaiju Cats.
