#!/bin/zsh
# Shared read-only monitor for the run folders used by transcribe.sh.
emulate -LR zsh

ROOT="${TRANSCRIPT_ROOT:-$HOME/Desktop/transcript-cleanup}"
[[ -d "$ROOT" ]] || {
  print "Workspace not found: $ROOT"
  exit 1
}

if [[ -x /opt/homebrew/opt/python@3.12/bin/python3.12 ]]; then
  MONITOR_PY=/opt/homebrew/opt/python@3.12/bin/python3.12
else
  MONITOR_PY=$(command -v python3) || exit 1
fi

"$MONITOR_PY" - "$ROOT" "$@" <<'PY_MONITOR'
import json, math, os, re, shutil, subprocess, sys, time
from datetime import datetime
from pathlib import Path

root = Path(sys.argv[1]).resolve()
once = "--once" in sys.argv[2:]
duration_cache = {}

def read(path, tail=False):
    try:
        with path.open("rb") as f:
            if tail:
                f.seek(0, 2)
                f.seek(max(0, f.tell() - 262144))
            return f.read().decode("utf-8", errors="replace")
    except OSError:
        return ""

def modified(path):
    try:
        return path.stat().st_mtime
    except OSError:
        return 0

def launcher():
    try:
        pid = int(read(root / ".transcribe.lock" / "pid").strip())
        if pid < 1:
            return None
        os.kill(pid, 0)
        result = subprocess.run(
            ["ps", "-p", str(pid), "-o", "command="],
            capture_output=True, text=True, timeout=2
        )
        return pid if "transcribe.sh" in result.stdout else None
    except (ValueError, OSError, subprocess.SubprocessError):
        return None

def latest_run(pid):
    files = list((root / "exports").glob("*/status.txt"))
    files += list((root / "completed").glob("*/status.txt"))
    files.sort(key=modified, reverse=True)
    if pid:
        for status in files:
            if (
                status.parent.parent.name == "exports"
                and status.parent.name.endswith("-" + str(pid))
                and read(status).strip() == "RUNNING"
            ):
                return status.parent
    return files[0].parent if files else None

def duration(audio):
    if not audio or not shutil.which("ffprobe"):
        return None
    try:
        stat = audio.stat()
        key = (str(audio), stat.st_size, stat.st_mtime_ns)
        if key not in duration_cache:
            result = subprocess.run(
                [
                    "ffprobe", "-v", "error",
                    "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1",
                    str(audio)
                ],
                capture_output=True, text=True, timeout=5
            )
            value = float(result.stdout.strip())
            if result.returncode or not math.isfinite(value) or value <= 0:
                return None
            duration_cache[key] = value
        return duration_cache[key]
    except (OSError, ValueError, subprocess.SubprocessError):
        return None

def clock(seconds):
    seconds = max(0, int(seconds))
    return (
        f"{seconds // 3600:02d}:"
        f"{seconds % 3600 // 60:02d}:"
        f"{seconds % 60:02d}"
    )

def bar(percent):
    percent = max(0.0, min(100.0, percent))
    filled = int(percent * 28 / 100)
    return (
        "[" + "█" * filled + "░" * (28 - filled)
        + f"] {percent:5.1f}%"
    )

def activity():
    return "◐◓◑◒"[int(time.monotonic()) % 4]

def snapshot():
    pid = launcher()
    run = latest_run(pid)
    lines = [
        "WHISPERX PROGRESS MONITOR",
        datetime.now().astimezone().strftime("%d %b %Y %H:%M:%S %Z"),
        ""
    ]

    if not run:
        lines.append(
            "Status: Waiting for a run folder "
            "(audio/options may still be being selected)."
        )
        lines.append(f"{activity()} Waiting — no progress percentage available.")
        return "\n".join(lines)

    state = read(run / "status.txt").strip() or "Status unavailable"
    try:
        meta = json.loads(read(run / "run.json"))
    except (ValueError, TypeError):
        meta = {}

    run_id = Path(meta.get("run", str(run))).name
    log = run / "whisperx.log"
    if not log.is_file():
        log = root / "logs" / (run_id + " - whisperx.log")

    text = read(log, tail=True)
    markers = list(re.finditer(
        r"Performing (transcription|alignment|diarization)",
        text, re.I
    ))
    stages = {
        "transcription": "Transcription",
        "alignment": "Word alignment",
        "diarization": "Speaker diarisation"
    }
    last = markers[-1] if markers else None
    phase = (
        stages[last.group(1).lower()]
        if last else "Stage unavailable in recent log"
    )
    if not last and "Transcript:" in text:
        phase = "Transcription"

    stage_text = text[last.end():] if last else text
    if not text:
        phase = "Audio conversion / initialisation"
    if list((run / "raw").glob("*.json")):
        phase = "Export validation / review / archiving"
    if state == "COMPLETE":
        phase = "Complete"
    elif state == "FAILED_OR_INTERRUPTED":
        phase = "Failed or interrupted — partial work retained"

    lines += [
        f"Run: {run.name}",
        f"Folder: {run}",
        f"Status: {state}",
        f"Stage: {phase}"
    ]

    active = bool(
        pid
        and run.parent.name == "exports"
        and run.name.endswith("-" + str(pid))
    )

    if state == "RUNNING" and not active:
        lines.append(
            "No live transcribe.sh launcher verified; "
            "this RUNNING status may be stale."
        )
    elif pid and not active:
        lines.append(
            "A launcher is active; it may be selecting a new run. "
            "Showing the latest recorded run."
        )

    if active:
        lines.append(f"Transcription launcher PID: {pid}")

    progress = re.findall(
        r"Progress:\s*([0-9]+(?:\.[0-9]+)?)%", stage_text
    )

    if state == "COMPLETE":
        lines.append("Run complete: " + bar(100))
    elif state == "FAILED_OR_INTERRUPTED":
        lines.append("Progress stopped; inspect the log below.")
    elif not active:
        lines.append("Activity unverified; no live progress bar shown.")
    elif progress and phase in ("Transcription", "Word alignment"):
        lines.append(phase + ": " + bar(float(progress[-1])))
        lines.append("Percentage applies to this stage, not the complete run.")
    else:
        lines.append(
            f"{activity()} {phase} — no reliable percentage reported."
        )

    timestamps = re.findall(
        r"Transcript:\s*\[[0-9.]+\s*-->\s*([0-9.]+)\]", text
    )
    waves = list(run.glob("* - voice enhanced.wav"))
    total = duration(waves[0]) if waves else None
    source = run / Path(meta.get("input", "")).name
    if total is None and source.is_file():
        total = duration(source)

    if total:
        lines.append(f"Audio duration: {clock(total)}")
    if timestamps:
        try:
            position = float(timestamps[-1])
            lines.append(
                f"Last transcribed audio position: {clock(position)}"
                + (f" / {clock(total)}" if total else "")
            )
        except ValueError:
            pass

    lines += ["", "LAST TRANSCRIPT LINES"]
    stream = [
        line for line in text.splitlines()
        if "Transcript:" in line
    ]
    lines += stream[-10:] or ["No transcript lines available yet."]

    lines += ["", "RAW EXPORTS"]
    exports = sorted(
        p.name for p in (run / "raw").glob("*")
        if p.is_file()
    )
    lines += exports or ["No raw exports written yet."]

    lines += ["", "LATEST LOG LINES"]
    lines += text.splitlines()[-6:] or ["WhisperX log not available yet."]

    if shutil.which("vm_stat"):
        try:
            result = subprocess.run(
                ["vm_stat"],
                capture_output=True, text=True, timeout=2
            )
            summary = [
                line for line in result.stdout.splitlines()
                if any(key in line for key in (
                    "page size", "Pages free:", "Pages wired down:",
                    "Pages occupied by compressor:"
                ))
            ]
            lines += ["", "MEMORY"] + summary
        except (OSError, subprocess.SubprocessError):
            pass

    lines += [
        "",
        "Refreshes every 10 seconds. Ctrl+C stops only this monitor."
    ]
    return "\n".join(lines)

try:
    while True:
        if not once and sys.stdout.isatty():
            print("\033[2J\033[H", end="")
        print(snapshot(), flush=True)
        if once:
            break
        time.sleep(10)
except KeyboardInterrupt:
    print("\nMonitor stopped; transcription was not interrupted.")
PY_MONITOR
