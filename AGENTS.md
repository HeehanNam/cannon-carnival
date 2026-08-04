# Cannon Carnival — Agent Guide

## Current project

- Engine: Godot 4.7.1 stable
- Main scene: `res://scenes/game.tscn`
- Main gameplay script: `res://scripts/game.gd`
- Block physics script: `res://scripts/physics_block.gd`
- Renderer: GL Compatibility
- Targets: Web preview first, then Android and iOS
- Viewport: portrait 540×960 with stretch enabled

`TowerGame_AGENTS.md` is the original long-form planning document. Some text in it has legacy encoding damage and several sections describe old behavior. This root `AGENTS.md` is authoritative for current implementation and development operations.

## Implemented gameplay contract

- Tap/click anywhere to fire at the selected 3D point; no drag aiming or Fire button.
- Consecutive shots are allowed while earlier projectiles are active.
- Blocks stay frozen until the first projectile impact, then normal physics applies.
- A level clears only after no block remains over the actual platform footprint.
- The platform is fitted to each generated structure; higher tiers use less margin.
- 50 deterministic levels use 10 structure families and five visual themes.
- Block materials include barrel, wood, stone, glass, ice, and explosive.
- Pause must preserve and restore the pre-pause game state.

Do not reintroduce target-only clear logic, unsupported floating structures, drag aiming, large camera shake, or a fixed platform size.

## Local validation

Use the same Godot major/minor version as CI.

```text
godot --headless --editor --path . --quit
godot --headless --single-threaded-scene --path . --script res://tests/level_generation_test.gd
godot --headless --path . --export-release "Web" build/web/index.html
```

The Web export requires Godot 4.7.1 export templates. `build/` is generated output and must not be committed.

## Remote Web preview

- Preset name: `Web`
- Preset file: `export_presets.cfg`
- Workflow: `.github/workflows/deploy-web.yml`
- Pull requests: parse, regression-test, and Web-export validation only
- `main` pushes: validate, export, and upload the downloadable `cannon-carnival-web` artifact
- Public repositories: also deploy to `https://heehannam.github.io/cannon-carnival/`
- Actions: `https://github.com/HeehanNam/cannon-carnival/actions`

The Pages preview uses a single-threaded Web export because GitHub Pages does not provide custom cross-origin isolation headers. Do not enable Web thread support without changing hosting and verifying headers.

The repository is currently private, and the current GitHub plan does not support private Pages. Keep CI and artifact upload working while private; if the repository becomes public, the workflow enables and deploys Pages automatically. Do not change repository visibility without explicit user approval.

## Remote smoke test

After deployment, verify on desktop and a mobile browser:

1. The portrait scene loads without a blank screen.
2. Touching the structure fires at the touched point.
3. Consecutive shots, collision, glass/ice effects, and explosions work.
4. Blocks fall and clear/fail resolves without getting stuck.
5. Pause → Continue resumes physics and input.
6. Next/retry loads the correct level and fitted platform.
7. UI remains usable around browser bars and device safe areas.

Web preview does not validate AdMob, native haptics, mobile background behavior, signing, or device GPU performance.

## Change discipline

- Preserve user changes and avoid broad rewrites.
- Stage only files belonging to the task. Do not stage `.codex-remote-attachments/`.
- Keep secrets, signing files, tokens, and mobile credentials out of the repository and Web export.
- Treat Linux paths as case-sensitive.
- When CI fails, inspect in order: YAML, Godot version, templates, preset name, script parse errors, missing/case-mismatched resources, then Pages settings.
- Report: implemented behavior, changed files, local validation, remote preview/check status, known issues, and next recommended task.
