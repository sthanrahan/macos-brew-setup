#!/usr/bin/env python3
"""Run WhisperX-compatible speaker diarisation independently of transcription."""

import argparse
import json
import os
import sys
import time
from pathlib import Path

import torch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True, type=Path)
    parser.add_argument("--transcript", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--device", choices=("cpu", "mps"), default="mps")
    parser.add_argument("--min-speakers", type=int)
    parser.add_argument("--max-speakers", type=int)
    args = parser.parse_args()

    if not args.audio.is_file():
        parser.error(f"Audio not found: {args.audio}")

    if not args.transcript.is_file():
        parser.error(f"Transcript not found: {args.transcript}")

    if args.output.exists():
        parser.error(f"Output already exists: {args.output}")

    if args.min_speakers and args.max_speakers:
        if args.min_speakers > args.max_speakers:
            parser.error("Minimum speakers exceeds maximum speakers")

    if args.device == "mps" and not torch.backends.mps.is_available():
        parser.error("Apple MPS is unavailable")

    from huggingface_hub import get_token
    from whisperx.audio import load_audio
    from whisperx.diarize import (
        DiarizationPipeline,
        assign_word_speakers,
    )

    token = get_token()
    if not token:
        parser.error("No cached Hugging Face token")

    transcript = json.loads(args.transcript.read_text(encoding="utf-8"))

    if not transcript.get("segments"):
        parser.error("Transcript contains no segments")

    print("=== INDEPENDENT DIARISATION ===", flush=True)
    print(f"Audio: {args.audio}", flush=True)
    print(f"Device: {args.device}", flush=True)
    print(f"Minimum speakers: {args.min_speakers}", flush=True)
    print(f"Maximum speakers: {args.max_speakers}", flush=True)

    started = time.monotonic()

    # WhisperX uses FFmpeg directly, avoiding TorchCodec's file decoder.
    waveform = load_audio(str(args.audio))

    print(
        f"Audio loaded: {len(waveform) / 16000:.1f} seconds",
        flush=True,
    )

    pipeline = DiarizationPipeline(
        model_name="pyannote/speaker-diarization-community-1",
        token=token,
        device=args.device,
    )

    last_progress = -1

    def progress_callback(*callback_args, **callback_kwargs):
        nonlocal last_progress

        percentage = None

        if callback_args:
            for value in reversed(callback_args):
                if isinstance(value, (float, int)):
                    percentage = float(value)
                    break

        if percentage is None:
            for key in ("progress", "percentage"):
                if key in callback_kwargs:
                    percentage = float(callback_kwargs[key])
                    break

        if percentage is None:
            return

        if percentage <= 1:
            percentage *= 100

        current = max(0, min(100, int(percentage)))

        if current >= last_progress + 5 or current == 100:
            last_progress = current
            print(
                f"Diarisation: {current}% "
                f"| elapsed {time.monotonic() - started:.1f}s",
                flush=True,
            )

    print("Starting diarisation...", flush=True)

    diarisation = pipeline(
        waveform,
        min_speakers=args.min_speakers,
        max_speakers=args.max_speakers,
        progress_callback=progress_callback,
    )

    result = assign_word_speakers(diarisation, transcript)

    args.output.parent.mkdir(parents=True, exist_ok=True)

    temporary = args.output.with_suffix(args.output.suffix + ".tmp")

    try:
        temporary.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        os.replace(temporary, args.output)
    finally:
        temporary.unlink(missing_ok=True)

    elapsed = time.monotonic() - started

    print(f"Completed in {elapsed:.1f} seconds", flush=True)
    print(f"Output: {args.output}", flush=True)


if __name__ == "__main__":
    main()
