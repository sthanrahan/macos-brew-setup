# Shared WhisperX transcription baseline

This directory preserves the shared transcription workflow used on:

- Shannon MBP 13 - M1 (2020)
- PHL MBP 16 - M1X (2021)

## Canonical files

- transcribe.sh — interactive WhisperX transcription workflow.
- whisperx-progress.sh — read-only progress monitor.
- requirements.txt — curated shared Python dependency baseline.
- maori_glossary.txt — shared vocabulary hints.
- snapshots/ — dated diagnostic environment records.

The dated snapshots are references, not installation requirements.

## Validated baseline

- Python 3.12
- WhisperX 3.8.5
- PyTorch, TorchAudio and TorchCodec 2.8.0 / 2.8.0 / 0.7.0
- pyannote.audio 4.0.4
- faster-whisper 1.2.1
- Hugging Face Hub 0.36.2

At validation on 9 October 2026, PyAV was 17.0.1 on Shannon and 17.1.0 on PHL.
This minor indirect-package difference does not alter the shared scripts.

## Operational location

The live folder is ~/Desktop/transcript-cleanup on each Mac.
The normal virtual environment is ~/Desktop/transcript-cleanup/whisperx-env.
WHISPERX_VENV may select another environment.

## Authentication

Diarisation requires a valid cached Hugging Face login.
Use hf auth login --force and verify with hf auth whoami.
No Hugging Face token is stored in this repository.

## FFmpeg

The normal Homebrew ffmpeg formula remains globally active.
Shannon also retains keg-only ffmpeg@7 for the current TorchCodec installation.
Do not globally link ffmpeg@7.

The duplicate AVFoundation-class warning on Shannon is non-fatal in the
validated configuration. A complete workflow succeeded on 8 October 2026.

## Expected script hashes

- transcribe.sh: 09a63efbbd9e62c82f0f9ef89d084d7b4c3a79cb63cd5624ff9ad40abc36737c
- whisperx-progress.sh: 5bb1490b260129e3d81be54e3036c3396c87ea6be1bbbe47420bbbd365ed3bc4

## Restoration status

The workflow is verified on both existing Macs.
A complete fresh-machine restoration has not yet been tested.
