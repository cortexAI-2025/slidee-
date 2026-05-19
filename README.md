# Slidee — Sliding Puzzle from Your Photos

A minimal, fast sliding-puzzle game for Android built with **Godot 4.3**.  
Pick any photo from your gallery, choose a difficulty, and solve the puzzle.

## Project Structure

```
slidee-/
├── project.godot              # Godot project config
├── export_presets.cfg         # Android export settings
├── scenes/
│   ├── Home.tscn              # Launch screen
│   ├── Difficulty.tscn        # Grid-size picker
│   ├── Game.tscn              # Main game
│   ├── Victory.tscn           # Results screen
│   └── Tile.tscn              # Individual puzzle tile
├── scripts/
│   ├── Autoload/
│   │   ├── GameManager.gd     # Global state singleton
│   │   └── SaveManager.gd     # JSON persistence (best scores)
│   ├── Home.gd
│   ├── Difficulty.gd
│   ├── Game.gd                # Timer, HUD, tile orchestration
│   ├── PuzzleBoard.gd         # Pure puzzle logic (shuffle, moves, win)
│   ├── Tile.gd                # Tile rendering + slide animation
│   ├── Victory.gd
│   └── ImagePickerPlugin.gd   # Cross-platform image picker abstraction
├── android/
│   └── build/
│       ├── build.gradle
│       ├── AndroidManifest.xml
│       └── src/main/java/com/slidee/puzzle/plugin/
│           └── ImagePickerPlugin.java   # Native Android gallery plugin
└── assets/
    └── icon.svg
```

## How to Build

### Requirements
- Godot 4.3+ (download from [godotengine.org](https://godotengine.org))
- Android SDK (API 34) + JDK 17
- Android NDK r23c (for Gradle build)

### Desktop testing
1. Open `project.godot` in the Godot editor.
2. Press **F5** to run. The FileDialog image picker works on desktop for testing.

### Android export
1. In Godot: **Project → Export → Android**.
2. Set your keystore and package name (`com.slidee.puzzle`).
3. Enable **Gradle Build** in export options.
4. Click **Export Project**.

### Native image picker plugin
The `ImagePickerPlugin.java` is a Godot Android plugin that opens the system  
photo picker. To activate it:
1. Compile the Java file into a `.aar` or include it in the Gradle build.
2. Register it in `project.godot` under `[android] modules`.
3. On first run the plugin registers itself as `"GodotImagePicker"` singleton.

On desktop / without the plugin the game falls back to Godot's `FileDialog`.

## Game Flow

```
Home ──[Select Image]──► ImagePicker
                              │
                         image_ready
                              │
                        Difficulty ──[3×3 / 4×4 / 5×5]──► Game
                                                               │
                                                          puzzle_solved
                                                               │
                                                           Victory
                                                               │
                                              [Play Again / Change Image / Home]
```

## Puzzle Logic

- **Shuffle**: starts from solved state, applies N random valid moves →  
  guaranteed solvable, no inversion-parity calculation needed.
- **Win detection**: `tiles[i] == i+1` for all `i`, `tiles[last] == 0`.
- **Tile animation**: `Tween` (TRANS_CUBIC / EASE_OUT, 120 ms).
- **Image slicing**: `AtlasTexture` sub-regions on a single `ImageTexture` →  
  zero pixel copying at runtime.

## Monetisation (stub)

`GameManager.should_show_ad()` returns `true` every 3 completed games unless  
`is_premium == true`. Wire your AdMob / Unity Ads SDK calls to that signal.  
Premium toggle is in the Settings popup on the Home screen (saved to disk).

## Saving Data

All persistence lives in `user://save_data.json` via `SaveManager`:

```json
{
  "best_scores": {
    "3": { "moves": 42, "time": 95.3 },
    "4": { "moves": -1, "time": -1.0 },
    "5": { "moves": -1, "time": -1.0 }
  },
  "games_completed": 5,
  "is_premium": false,
  "dark_mode": false
}
```
