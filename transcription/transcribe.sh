#!/bin/zsh
# Canonical shared transcription baseline for both managed Macs, 2026-10-07.
# Run this script; never source it.

emulate -LR zsh
setopt ERR_EXIT PIPE_FAIL NO_UNSET
umask 077

ROOT="${TRANSCRIPT_ROOT:-$HOME/Desktop/transcript-cleanup}"
cd "$ROOT" || exit 1
ROOT="$PWD"

HF_CLI=$(command -v hf || true)

VENV="${WHISPERX_VENV:-}"
if [[ -z "$VENV" ]]; then
  if [[ -x "$ROOT/whisperx-env/bin/python3" ]]; then
    VENV="$ROOT/whisperx-env"
  else
    VENV="$HOME/.venvs/whisperx"
  fi
fi

[[ -x "$VENV/bin/python3" ]] || {
  print "WhisperX environment not found: $VENV"
  exit 1
}

for tool in ffmpeg ffprobe; do
  command -v "$tool" >/dev/null || {
    print "Missing tool: $tool"
    exit 1
  }
done

mkdir -p incoming exports completed Projects logs

LOCK="$ROOT/.transcribe.lock"

if ! mkdir "$LOCK" 2>/dev/null; then
  print "Another run, or an interrupted run's lock, exists: $LOCK"
  print "Check its pid file and running processes before removing this lock."
  exit 1
fi

print -r -- "$$" > "$LOCK/pid"

RUN=""
DONE=0

finish() {
  if [[ -n "$RUN" && -d "$RUN" && "$DONE" == 0 ]]; then
    print -r -- "FAILED_OR_INTERRUPTED" > "$RUN/status.txt"
    print -r -- "Run stopped. Original audio is untouched; available work is in $RUN"
  fi

  rm -f "$LOCK/pid"
  rmdir "$LOCK" 2>/dev/null || true
}

trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

print ""
print "========================================="
print "        WHISPERX TRANSCRIPTION TOOL"
print "        Shared Two-Mac Baseline"
print "========================================="
print ""

files=(./*(.N) incoming/*(.N))
audio=()

for item in "${files[@]}"; do
  case "${item:e:l}" in
    m4a|wav|mp3|mp4|aac|flac|aiff|aif|ogg|opus|mov)
      [[ "${item:t}" == *' - voice enhanced.wav' ]] ||
        audio+=("$item")
      ;;
  esac
done

(( ${#audio} )) || {
  print "No supported audio in the workspace root or incoming/."
  exit 1
}

print "Available audio files:"
print ""

for (( i=1; i<=${#audio}; i++ )); do
  print -r -- "$i) ${audio[$i]}"
done

print ""

while true; do
  read "selection?Select audio number: "

  if [[ "$selection" == <-> ]] &&
      (( selection >= 1 && selection <= ${#audio} )); then
    INPUT="${audio[$selection]}"
    break
  fi

  print "Select a listed number."
done

INPUT="${INPUT:A}"

print ""
print -r -- "Selected: ${INPUT:t}"
print ""

print "Speaker count?"
print "1) One speaker"
print "2) Two speakers"
print "3) Three speakers"
print "4) Four speakers"
print "5) Five or more"
print "6) Unknown / uncertain"
read "choice?Choose [6]: "

DIARIZE=1
SPEAKER_ARGS=()

case "$choice" in
  1)
    DIARIZE=0
    ;;
  2|3|4)
    SPEAKER_ARGS=(--min_speakers "$choice" --max_speakers "$choice")
    ;;
  5)
    SPEAKER_ARGS=(--min_speakers 5)
    ;;
  6|'')
    ;;
  *)
    print "Invalid speaker choice."
    exit 1
    ;;
esac

print ""
print "Language context?"
print "1) Mostly English"
print "2) English with some te reo Māori"
print "3) Mixed English / te reo Māori"
print "4) Predominantly te reo Māori"
read "choice?Choose [2]: "

LANG_CONTEXT="${choice:-2}"

LANG_CODE=en
ALIGN_ARGS=()
MODEL=large-v3

case "$choice" in
  1)
    MODEL=medium
    ;;
  2|'')
    ;;
  3)
    ALIGN_ARGS=(--no_align)
    ;;
  4)
    LANG_CODE=mi
    ALIGN_ARGS=(--no_align)
    ;;
  *)
    print "Invalid language choice."
    exit 1
    ;;
esac

print ""
print "Whisper model?"
print "1) Recommended for selected language ($MODEL)"
print "2) large-v3"
print "3) medium"
read "choice?Choose [1]: "

case "$choice" in
  1|'')
    ;;
  2)
    MODEL=large-v3
    ;;
  3)
    MODEL=medium
    ;;
  *)
    print "Invalid model choice."
    exit 1
    ;;
esac

print ""
print "Audio processing?"
print "1) Standard conversion"
print "2) Speech enhancement for noisy audio"
read "choice?Choose [1]: "

FILTER_ARGS=()

case "$choice" in
  1|'')
    ;;
  2)
    FILTER_ARGS=(
      -af
      'highpass=f=75,lowpass=f=7800,afftdn=nf=-20,acompressor=threshold=-18dB:ratio=2.5:attack=20:release=250,loudnorm=I=-16:TP=-1.5:LRA=11'
    )
    ;;
  *)
    print "Invalid audio choice."
    exit 1
    ;;
esac

print ""
print "Repeated-text detection sensitivity?"
print "1) Conservative — 10 repetitions"
print "2) Balanced — 6 repetitions"
print "3) Aggressive — 3 repetitions"
read "choice?Choose [1]: "

THRESHOLD=10

case "$choice" in
  1|'')
    ;;
  2)
    THRESHOLD=6
    ;;
  3)
    THRESHOLD=3
    ;;
  *)
    print "Invalid threshold."
    exit 1
    ;;
esac

print ""
print "Repeated-text handling?"
print "1) Flag for review only"
print "2) Replace in a separate review transcript"
read "choice?Choose [1]: "

ACTION=audit

case "$choice" in
  1|'')
    ;;
  2)
    ACTION=replace
    ;;
  *)
    print "Invalid action."
    exit 1
    ;;
esac

CONTEXT=$("$VENV/bin/python3" - <<'PY_CONTEXT'
from pathlib import Path

p = Path("maori_glossary.txt")
terms = []

if p.exists():
    for line in p.read_text(
        encoding="utf-8-sig"
    ).splitlines():
        line = line.strip()

        if (
            line
            and not line.startswith("#")
            and line.casefold()
            not in {s.casefold() for s in terms}
        ):
            if len("; ".join(terms + [line])) > 700:
                break

            terms.append(line)
else:
    terms = [
        "Kia ora",
        "Aotearoa",
        "Māori",
        "whānau",
        "hui",
        "kaupapa",
        "kōrero",
        "hauora",
        "hapori",
    ]

print(
    "Vocabulary hints: "
    + "; ".join(terms)
    + "."
)
PY_CONTEXT
)

print ""
print -r -- "Default context prompt:"
print -r -- "$CONTEXT"
print ""
read "custom?Optional context prompt (Enter to keep default): "

[[ -z "$custom" ]] || CONTEXT="$custom"

if (( DIARIZE )); then
  [[ -n "$HF_CLI" ]] || {
    print "Hugging Face CLI not found."
    print "Use the shell where 'hf auth whoami' works."
    exit 1
  }

  env \
    -u HF_TOKEN \
    -u HUGGING_FACE_HUB_TOKEN \
    "$HF_CLI" auth whoami || {
      print "Hugging Face login failed."
      print "Run: hf auth login --force"
      exit 1
    }
fi

# Some venv activation scripts reference this before defining it.
# Initialise it for compatibility with zsh NO_UNSET.
: "${DYLD_FALLBACK_LIBRARY_PATH:=}"
export DYLD_FALLBACK_LIBRARY_PATH

source "$VENV/bin/activate"

unset HF_TOKEN
unset HUGGING_FACE_HUB_TOKEN

export PYTHONUNBUFFERED=1

BASE="${INPUT:t:r}"
ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN="$ROOT/exports/$ID"

mkdir "$RUN"
mkdir "$RUN/raw"

print -r -- "RUNNING" > "$RUN/status.txt"

LOG="$ROOT/logs/$ID - whisperx.log"
OUTPUT="$RUN/$BASE - voice enhanced.wav"

# Keep a protected copy of the original audio with this run.
# The source copy is removed only after the entire run succeeds.
cp -p "$INPUT" "$RUN/${INPUT:t}"

print ""
print "=== Converting Audio ==="

ffmpeg \
  -nostdin \
  -n \
  -i "$INPUT" \
  -vn \
  -ac 1 \
  -ar 16000 \
  "${FILTER_ARGS[@]}" \
  -c:a pcm_s16le \
  "$OUTPUT" \
  2>&1 | tee "$RUN/audio-conversion.log"

export TX_RUN="$RUN"
export TX_INPUT="$INPUT"
export TX_MODEL="$MODEL"
export TX_LANGUAGE="$LANG_CODE"
export TX_LANG_CONTEXT="$LANG_CONTEXT"
export TX_THRESHOLD="$THRESHOLD"
export TX_ACTION="$ACTION"
export TX_DIARIZE="$DIARIZE"
export TX_CONTEXT="$CONTEXT"
export TX_ALIGNMENT="${ALIGN_ARGS[*]:-default}"
export TX_FILTER="${FILTER_ARGS[*]:-standard conversion}"

python3 - <<'PY_META'
import json
import os
import platform
from pathlib import Path
from importlib.metadata import (
    version,
    PackageNotFoundError,
)

packages = {}

for name in (
    "whisperx",
    "huggingface_hub",
    "torch",
    "torchaudio",
    "pyannote.audio",
    "faster-whisper",
):
    try:
        packages[name] = version(name)
    except PackageNotFoundError:
        packages[name] = "not installed"

keys = (
    "RUN",
    "INPUT",
    "MODEL",
    "LANGUAGE",
    "LANG_CONTEXT",
    "THRESHOLD",
    "ACTION",
    "DIARIZE",
    "CONTEXT",
    "ALIGNMENT",
    "FILTER",
)

meta = {
    k.lower(): os.environ["TX_" + k]
    for k in keys
}

meta.update(
    python=platform.python_version(),
    architecture=platform.machine(),
    packages=packages,
)

Path(
    os.environ["TX_RUN"],
    "run.json",
).write_text(
    json.dumps(
        meta,
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
PY_META

ARGS=(
  "$OUTPUT"
  --model "$MODEL"
  --language "$LANG_CODE"
  --task transcribe
  --device cpu
  --compute_type int8
  --batch_size 2
  --vad_method silero
  --output_dir "$RUN/raw"
  --output_format all
  --initial_prompt "$CONTEXT"
  --print_progress True
  "${ALIGN_ARGS[@]}"
)

if (( DIARIZE )); then
  ARGS+=(
    --diarize
    "${SPEAKER_ARGS[@]}"
  )
fi

print ""
print "=== Starting WhisperX ==="

# Hugging Face token is obtained inside Python.
# It is not exposed in the shell command line.
python3 - "${ARGS[@]}" <<'PY_WHISPER' 2>&1 | tee "$LOG"
import os
import sys

from huggingface_hub import (
    HfApi,
    get_token,
)

if os.environ["TX_DIARIZE"] == "1":
    token = get_token()

    if not token:
        sys.exit(
            "No cached Hugging Face login. "
            "Run: hf auth login --force"
        )

    try:
        HfApi().whoami(token=token)
    except Exception:
        sys.exit(
            "Cached Hugging Face login was rejected. "
            "Run: hf auth login --force"
        )

    sys.argv.extend(
        ["--hf_token", token]
    )

from whisperx.__main__ import cli

cli()
PY_WHISPER

print ""
print "=== Validating and Reviewing Transcript ==="

python3 - <<'PY_REVIEW'
import os
import json
import re
import unicodedata
from pathlib import Path

run = Path(os.environ["TX_RUN"])

results = list(
    (run / "raw").glob("*.json")
)

if len(results) != 1:
    raise SystemExit(
        "Expected one WhisperX JSON result; "
        "partial work retained."
    )

data = json.loads(
    results[0].read_text(
        encoding="utf-8"
    )
)

segments = data.get(
    "segments",
    [],
)

if not segments or not any(
    str(
        s.get("text", "")
    ).strip()
    for s in segments
):
    raise SystemExit(
        "No speech text was exported; "
        "review audio/VAD settings. "
        "Work retained."
    )

for ext in (
    "txt",
    "srt",
    "vtt",
):
    if not list(
        (run / "raw").glob(
            "*." + ext
        )
    ):
        raise SystemExit(
            "Missing raw "
            + ext
            + " export; "
            "partial work retained."
        )

threshold = int(
    os.environ["TX_THRESHOLD"]
)

action = os.environ["TX_ACTION"]

word = (
    r"[^\W\d_]+"
    r"(?:['’][^\W\d_]+)*"
)

patterns = [
    re.compile(
        r"(?<!\w)("
        + word
        + r"(?:[ \t]+"
        + word
        + r"){"
        + str(n - 1)
        + r"})"
        + r"(?:[ \t,;.!?]+\1){"
        + str(threshold - 1)
        + r",}(?!\w)",
        re.I,
    )
    for n in range(
        4,
        0,
        -1,
    )
]

flags = []
lines = []
all_text = []

for index, segment in enumerate(
    segments,
    1,
):
    raw = str(
        segment.get(
            "text",
            "",
        )
    ).strip()

    text = raw
    spans = []

    for pattern in patterns:

        def replace(match):
            if action == "audit":
                if any(
                    match.start() < end
                    and match.end() > start
                    for start, end in spans
                ):
                    return match.group(0)

                spans.append(
                    match.span()
                )

            flags.append(
                {
                    "segment": index,
                    "start": segment.get(
                        "start"
                    ),
                    "end": segment.get(
                        "end"
                    ),
                    "original": match.group(
                        0
                    ),
                    "action": action,
                }
            )

            if action == "replace":
                return (
                    "[repetition flagged "
                    "for review]"
                )

            return match.group(0)

        text = pattern.sub(
            replace,
            text,
        )

    default_speaker = (
        "SPEAKER_00"
        if os.environ[
            "TX_DIARIZE"
        ]
        == "0"
        else "SPEAKER_UNKNOWN"
    )

    speaker = segment.get(
        "speaker",
        default_speaker,
    )

    lines.append(
        f"[{segment.get('start', 0):.2f}"
        f"–{segment.get('end', 0):.2f}] "
        f"{speaker}: {text}"
    )

    all_text.append(raw)

notice = (
    "REVIEW COPY — repeated text is a "
    "candidate for review, not proof of "
    "hallucination.\n"
    "Raw exports in raw/ are unchanged."
    "\n\n"
)

(
    run / "transcript-review.txt"
).write_text(
    notice
    + "\n".join(lines)
    + "\n",
    encoding="utf-8",
)

(
    run / "repetition-audit.json"
).write_text(
    json.dumps(
        {
            "threshold": threshold,
            "action": action,
            "detections": flags,
        },
        ensure_ascii=False,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)

glossary = Path(
    "maori_glossary.txt"
)

known = set()

if glossary.exists():
    content = unicodedata.normalize(
        "NFC",
        glossary.read_text(
            encoding="utf-8-sig"
        ),
    )

    known = {
        w.casefold()
        for w in re.findall(
            word,
            content,
        )
    }

if (
    os.environ.get(
        "TX_LANG_CONTEXT"
    )
    == "1"
):
    candidates = []
else:
    candidates = sorted(
        {
            w.casefold()
            for w in re.findall(
                word,
                unicodedata.normalize(
                    "NFC",
                    " ".join(
                        all_text
                    ),
                ),
            )
            if any(
                c in w.casefold()
                for c in "āēīōū"
            )
            and w.casefold()
            not in known
        }
    )

(
    run / "pending_vocabulary.txt"
).write_text(
    "# Macron-bearing candidates only; "
    "verify spelling, context and language "
    "before adding.\n"
    + "\n".join(candidates)
    + "\n",
    encoding="utf-8",
)

print(
    "Validated exports. "
    f"Repeated-text detections: "
    f"{len(flags)}. "
    f"Vocabulary candidates: "
    f"{len(candidates)}."
)
PY_REVIEW

mv "$LOG" "$RUN/whisperx.log"

DEST="$ROOT/completed/$BASE"

if [[ -e "$DEST" ]]; then
  DEST="$ROOT/completed/$BASE [$ID]"
fi

mv "$RUN" "$DEST"
RUN="$DEST"

print -r -- "COMPLETE" > "$RUN/status.txt"

DONE=1

# The source audio was copied into this archive
# before transcription. Remove the workspace copy
# only after every processing stage has succeeded.
if rm -f -- "$INPUT"; then
  print ""
  print "Original audio moved into completed archive."
else
  print ""
  print "WARNING:"
  print "Completed archive is valid, but the original"
  print "audio could not be removed from its source location."
fi

print ""
print "========================================="
print " COMPLETE"
print "========================================="
print ""
print -r -- "Archived to:"
print -r -- "$DEST"
print ""
print "Raw WhisperX exports, review transcript,"
print "audit data, vocabulary candidates and"
print "source audio are archived together."
