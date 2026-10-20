#!/usr/bin/env python3
"""Optional, offline speaker naming for a completed WhisperX run.

Usage: python3 identify-speakers.py /path/to/run
Rerun to revise names without retranscribing. Raw outputs remain unchanged.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

LABEL = re.compile(r'(?m)^(\[[^\n\]]+\]\s*)(SPEAKER_\d+|SPEAKER_UNKNOWN)(?=:)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path, help='Run or completed archive folder')
    args = parser.parse_args()
    run = args.run.expanduser().resolve()
    review = run / 'transcript-review.txt'
    raw = list((run / 'raw').glob('*.json'))
    if not review.is_file() or len(raw) != 1:
        parser.error('Expected transcript-review.txt and exactly one raw/*.json')
    original = review.read_text(encoding='utf-8')
    diarized = run / 'diarized.json'
    source = diarized if diarized.is_file() else raw[0]
    data = json.loads(source.read_text(encoding='utf-8'))
    segments = data.get('segments', [])
    labels = sorted({m.group(2) for m in LABEL.finditer(original)})
    if not labels:
        print('No speaker labels found. Original transcript retained.')
        return 0
    prior_file = run / 'speaker-map.json'
    prior = {}
    if prior_file.exists():
        prior_data = json.loads(prior_file.read_text(encoding='utf-8'))
        prior = prior_data.get('speakers', {})
    print('\n=== SPEAKER IDENTIFICATION (optional) ===')
    print('Names are NOT inferred from the order of speech.')
    print('Press Enter to keep an existing name or leave the ID unchanged.')
    mapping = {}
    for label in labels:
        print(f'\n{label} — example excerpts:')
        examples = [s for s in segments if s.get('speaker') == label and str(s.get('text', '')).strip()]
        for s in examples[:3]:
            excerpt = ' '.join(str(s['text']).split())[:130]
            print(f"  [{float(s.get('start', 0)):.1f}s] {excerpt}")
        if not examples:
            print('  (No labelled JSON segments; consult review transcript.)')
        # Preview optional and always manually selected; avoid temporary files in archive.
        if examples and shutil.which('ffmpeg') and shutil.which('afplay'):
            sources = [p for p in run.iterdir() if p.is_file() and p.suffix.lower() in
                       {'.m4a', '.wav', '.mp3', '.mp4', '.aac', '.flac', '.aiff', '.aif', '.ogg', '.opus', '.mov'}
                       and not p.name.endswith(' - voice enhanced.wav')]
            if sources and input('Play first example (up to 10 seconds)? [y/N]: ').strip().lower() == 'y':
                s = examples[0]
                start = max(0, float(s.get('start', 0)))
                duration = min(10, max(1, float(s.get('end', start + 10)) - start))
                with tempfile.TemporaryDirectory(prefix='speaker-preview-') as tmp:
                    clip = Path(tmp) / 'preview.wav'
                    result = subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin',
                                             '-ss', str(start), '-i', str(sources[0]), '-t', str(duration),
                                             '-vn', '-ac', '1', '-ar', '16000', str(clip)], check=False)
                    if result.returncode == 0:
                        subprocess.run(['afplay', str(clip)], check=False)
                    else:
                        print('Audio preview unavailable; transcript examples remain available.')
        existing = prior.get(label, label)
        answer = input(f'Name for {label} [{existing}]: ').strip()
        name = answer or existing
        if '\n' in name or '\r' in name or ':' in name:
            print('Names cannot contain colons or line breaks.', file=sys.stderr)
            return 2
        mapping[label] = name
    print('\nProposed mapping:')
    for label, name in mapping.items():
        print(f'  {label} -> {name}')
    if input('Save named transcript and mapping? [y/N]: ').strip().lower() != 'y':
        print('Skipped. Existing files unchanged.')
        return 0
    # Only change speaker labels at the start of transcript lines, not spoken words.
    named = LABEL.sub(lambda m: m.group(1) + mapping[m.group(2)], original)
    target = run / 'transcript-named.txt'
    map_target = run / 'speaker-map.json'
    # Prepare both outputs before replacing either existing file.
    with tempfile.TemporaryDirectory(prefix='.speaker-write-', dir=run) as tmp:
        temp = Path(tmp)
        (temp / target.name).write_text(named, encoding='utf-8')
        (temp / map_target.name).write_text(json.dumps({'schema_version': 1, 'speakers': mapping},
                                                         ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        (temp / target.name).replace(target)
        (temp / map_target.name).replace(map_target)
    print(f'Created: {target}\nCreated: {map_target}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (EOFError, KeyboardInterrupt):
        print('\nSpeaker naming skipped; transcript preserved.')
        sys.exit(0)
