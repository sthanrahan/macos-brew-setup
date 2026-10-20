# Shared WhisperX transcription baseline

This directory preserves the shared transcription workflow used on:

- Shannon MBP 13 - M1 (2020)
- PHL MBP 16 - M1X (2021)

## Canonical files

- transcribe.sh — interactive transcription, alignment, independent diarisation and transcript review.
- diarize-separately.py — independent speaker diarisation.
- identify-speakers.py — optional speaker naming.
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

The canonical scripts are maintained in ~/.dotfiles/transcription/.
The live workspace is ~/Desktop/transcript-cleanup on each Mac.
The normal virtual environment is ~/Desktop/transcript-cleanup/whisperx-env.
WHISPERX_VENV may select another environment.

Deploy the following files together from the canonical directory to the live workspace:

- transcribe.sh
- diarize-separately.py
- identify-speakers.py

Review local differences before replacing existing live scripts. Do not deploy during an active transcription run.

## Processing architecture

WhisperX performs transcription and alignment first.
When diarisation is requested, a separate Python process runs speaker diarisation using PyTorch MPS.
The original WhisperX JSON is preserved. Speaker assignments are saved separately in diarized.json and incorporated into the human-readable review transcript.
Optional speaker naming occurs after successful archiving.

MPS diarisation has been validated on both PHL and Shannon.

### Shannon end-to-end validation — 20 October 2026

Machine: Shannon MBP 13 - M1 (2020).

Validation recording: 60-second WAV test sample.

Result: COMPLETE.

The following stages completed successfully:

- FFmpeg audio conversion.
- WhisperX medium-model transcription.
- Word-level alignment.
- Independent MPS speaker diarisation using pyannote/speaker-diarization-community-1.
- Preservation of the original WhisperX JSON.
- Creation of separate diarized.json.
- Transcript validation and review.
- Optional speaker identification and named transcript generation.
- Archiving of source audio, transcription outputs and audit data.

Independent diarisation completed in 9.1 seconds.

The test detected one speaker. Multi-speaker identification accuracy and bilingual transcription accuracy were not established by this test.

Completed archive:
~/Desktop/transcript-cleanup/completed/whisperx-validation-20261020

The existing PyAV/FFmpeg duplicate Objective-C class warnings remain observable but did not prevent successful execution. Do not alter the working FFmpeg configuration solely to eliminate these warnings.


## Authentication

Diarisation requires a valid cached Hugging Face login.
Use hf auth login --force and verify with hf auth whoami.
No Hugging Face token is stored in this repository.

## FFmpeg

The normal Homebrew ffmpeg formula remains globally active.
Shannon also retains keg-only ffmpeg@7 for the current TorchCodec installation.
Do not globally link ffmpeg@7.

The earlier Shannon configuration produced duplicate AVFoundation-class
warnings involving PyAV and FFmpeg libraries. A complete workflow
succeeded on 8 October 2026, but the underlying library collision
was not resolved.

The newer PHL workflow separates transcription and diarisation into
different Python processes. Completed PHL runs produced speaker-labelled
transcripts without duplicate Objective-C class warnings in their logs.
TorchCodec library-loading warnings remain present in those logs.
Do not globally modify DYLD_LIBRARY_PATH or relink ffmpeg@7 merely
to suppress these warnings.

## Expected script hashes

- transcribe.sh: 8f709fccf2ae1084cc902dd2b82b83214180a060647ac454816b5f8811b23820
- whisperx-progress.sh: 5bb1490b260129e3d81be54e3036c3396c87ea6be1bbbe47420bbbd365ed3bc4
- diarize-separately.py: d1a6c15c56f93056797aaa454e50aabbd20912e5e6b6344af4d11110b65f1bf8
- identify-speakers.py: 5c2ecdd5882da291829322eadf209dc16919038057447db5d10447c39cc5b648

## Restoration status

The workflow is verified on both existing Macs.
A complete fresh-machine restoration has not yet been tested.
