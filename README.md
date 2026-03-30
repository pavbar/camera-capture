# camera-capture

`camera-capture` is a public macOS camera tool built around two workflows:
- real capture through a dedicated helper executable
- deterministic simulated capture for fast local verification and no-hardware environments

The project is intentionally test-heavy. The simulated backend is a product feature, not hidden test scaffolding.

## Quick start

```bash
./scripts/install.sh
camera-capture list-presets
camera-capture capture --backend simulated --preset framing-grid
```

The default capture path is `~/Pictures/Camera Capture/<timestamp>.jpg`.

## Install

Install the CLI into `~/.local/bin` and the helper app into `~/Applications`:

```bash
./scripts/install.sh
```

Dry-run first:

```bash
./scripts/install.sh --dry-run
```

Install into a custom directory:

```bash
./scripts/install.sh --prefix "$HOME/bin"
```

Uninstall later:

```bash
./scripts/uninstall.sh
```

Notes:
- install copies `camera-capture` into `~/.local/bin`
- install assembles and installs `Camera Capture Helper.app` into `~/Applications`
- existing installed binaries are backed up before being replaced
- if the install directory is not on `PATH`, the script prints a reminder
- `camera-capture` looks for `Camera Capture Helper.app` in `~/Applications` by default
- override discovery with `CAMERA_CAPTURE_HELPER_APP=/path/to/Camera\ Capture\ Helper.app`
- `CAMERA_CAPTURE_HELPER_PATH` still works as a lower-level escape hatch for direct executable paths

## Commands

```bash
camera-capture capture [--output <path>] [--camera <id|name>] [--preview] [--delay <seconds>] [--backend real|simulated] [--preset <name>]
camera-capture preview [--camera <id|name>] [--seconds <seconds> | --stay-open]
camera-capture list-devices
camera-capture request-access
camera-capture list-presets
```

### `capture`

Captures one image and prints the absolute output path on success.

Options:
- `--output <path>`: write the JPEG to an explicit path. If omitted, the file is written to `~/Pictures/Camera Capture/<timestamp>.jpg`.
- `--backend real|simulated`: choose between the real camera flow and the synthetic deterministic backend. Default is `real`.
- `--camera <id|name>`: select a specific real camera by exact device id or by name match. This only works with `--backend real`.
- `--preview`: show a small preview window before taking a real photo. This only works with `--backend real`.
- `--delay <seconds>`: wait before taking the shot. For real capture, this gives you time to frame the image or let autofocus settle. For preview mode, it controls how long the preview stays open before capture. For simulated capture, it is accepted by the parser only when the backend is real, because the simulated backend does not need a timing delay.
- `--preset <name>`: choose a simulated image style or failure mode. This only works with `--backend simulated`.

Simulated presets:
- `balanced`: neutral default synthetic image.
- `framing-grid`: synthetic frame with rule-of-thirds grid overlay.
- `soft-focus`: softer-looking synthetic output.
- `low-light`: darker synthetic image to emulate dim conditions.
- `no-signal`: synthetic degraded/noisy scene.
- `timeout`: intentionally fails with a timeout error for negative-path testing.
- `write-failure`: intentionally fails with a write error for negative-path testing.

Behavior notes:
- `capture --backend simulated` never requests Camera permission.
- `capture --backend real` launches `Camera Capture Helper.app`, so macOS Camera permission should be attributed to the helper app rather than the terminal host.
- existing files are not overwritten; choose a new output path instead.

### `preview`

Opens a live real-camera preview window without taking a picture.

Options:
- `--camera <id|name>`: select a specific real camera by exact device id or by name match.
- `--seconds <seconds>`: keep the preview window open for a fixed amount of time, then close it automatically.
- `--stay-open`: keep the preview window open until you close it manually.

Behavior notes:
- `preview` is a real-camera command only. It does not support the simulated backend.
- if you do not pass `--seconds` or `--stay-open`, the preview stays open for 10 seconds by default.
- `preview` never writes a file.
- `preview` also runs through `Camera Capture Helper.app`, so the helper app owns Camera permission for this flow.

### `list-devices`

Lists available real camera devices in `id<TAB>name` format. Use this to discover the value for `--camera`.

### `request-access`

Requests macOS Camera permission for the real-camera flow and prints the resulting state:
- `granted`
- `denied`
- `restricted`

If permission has not been requested yet, this command triggers the prompt and then prints the resulting final state.

### `list-presets`

Lists all available simulated presets. This is the fastest way to discover the public simulation surface without reading source code.

## Examples

Simulated capture:

```bash
camera-capture capture --backend simulated --preset low-light
```

Real capture with preview:

```bash
camera-capture capture --backend real --preview --delay 3
```

Standalone live preview:

```bash
camera-capture preview --camera "<camera-name>" --stay-open
```

## Development without install

If you are working on the repo itself and do not want to install binaries yet, use SwiftPM directly:

```bash
swift build
swift test
swift run camera-capture list-presets
swift run camera-capture capture --backend simulated --preset framing-grid
```

## Contributor workflow

- Follow strict TDD. Start with a failing test.
- Prefer simulation-backed tests and local verification first.
- Run `./scripts/verify.sh` before creating a commit you intend to keep or share, and again before pushing.

```bash
./scripts/verify.sh
```

- Optional local privacy overlay:
  Create `~/.config/privacy-scan/local-identifiers.txt` to scan for personal-only identifiers without committing them to the repo. Blank lines and `#` comments are ignored. Entries are treated as literal strings by default; prefix a line with `re:` only when you intentionally want a regex.
- Real camera permission and physical camera behavior still require a manual smoke test on macOS.

## Docs

- [PRD.md](PRD.md) - living product document
- [AGENTS.md](AGENTS.md) - repo-scoped contribution rules
- [INDEX.md](INDEX.md) - canonical repository structure map
- [CHANGELOG.md](CHANGELOG.md) - chronological repo history
- [LICENSE](LICENSE) - Apache License 2.0

## Brand assets

- Source art lives under `Assets/Brand/`
- Derived helper-app icon assets are generated into `Assets/Brand/derived/`
- Installed artifacts carry a shared build stamp in `camera-capture.build-info` and `Camera Capture Helper.app/Contents/Resources/BuildInfo.txt`
- Re-generate them with:

```bash
./scripts/generate_brand_assets.sh
```
