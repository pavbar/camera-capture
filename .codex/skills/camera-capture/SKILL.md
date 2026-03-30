---
name: camera-capture
description: Capture a real photo with the local `camera-capture` CLI, then hand the output path back for follow-up analysis.
---

# camera-capture

Use this skill when the task needs a fresh real-camera image from the local `camera-capture` tool.

## Workflow

1. Check whether the CLI is available:

```bash
camera-capture --help
```

2. If the CLI is unavailable, stop and tell the user that `camera-capture` is not installed or not on `PATH`.

3. If camera permission may not be granted yet, run:

```bash
camera-capture request-access
```

4. If the user needs framing first, run:

```bash
camera-capture preview --camera "<camera-id>" --stay-open
```

5. Capture a real photo:

```bash
camera-capture capture --backend real --camera "<camera-id>" --preview --delay 3
```

6. Return the absolute output path to the caller.
7. If the task asks for analysis, attach the captured image in the same flow.

## Notes

- This skill is for real camera capture, not simulated images.
- Default output lands under `~/Pictures/Camera Capture/`.
- Do not store personal photos or identifying environment details in tracked files.
