# Baconhub

Open source Roblox hub I made for fun.

Website: https://bigmoneycheese.github.io/Baconhub/

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/bigmoneycheese/Baconhub/main/main.lua"))()
```

## About

Baconhub is a lightweight Roblox script hub.

## Supported Games

- `+1 Health Per Click`
- `Gun Evolution`
- `Slime RNG`
- `+1 Shrink per Step`
- `Forsaken`
- `SLAP`
- `Spin a Soccer Card`
- `untitled tag game`

## Features

Features depend on the game, but scripts may include:

- Automation toggles
- Farming helpers
- Movement helpers
- Reward claiming
- Rebirth or upgrade automation
- Rayfield UI controls

## Repository Structure

```text
main.lua              Main loader
scripts/             Game-specific scripts
```

## Adding A Game

1. Create a new script in `scripts/`.
2. Add the game's `game.GameId` to `main.lua`.
3. Point the loader entry to the matching raw GitHub URL.
4. Keep game-specific logic inside the script file, not in `main.lua`.

## Notes

This project is for fun. Expect game updates to occasionally break features.
