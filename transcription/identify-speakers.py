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
from datetime import datetime
from pathlib import Path

LABEL = re.compile(r'(?m)^(\[[^\n\]]+\]\s*)(SPEAKER_\d+)(?=:)')


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
    print('Names are NOT inferred from the order or amount of speech.')
    print('Press Enter to keep an existing name or leave the ID unchanged.')
    mapping = {}
    records = {}
    for label in labels:
        print(f'\n{label} — example excerpts:')
        examples = [s for s in segments if s.get('speaker') == label and str(s.get('text', '')).strip()]
        for s in (examples[:3] + examples[len(examples)//2:len(examples)//2+2] + examples[-2:]):
            excerpt = ' '.join(str(s['text']).split())[:130]
            print(f"  [{float(s.get('start', 0)):.1f}s] {excerpt}")
        if not examples:
            print('  (No labelled JSON segments; consult review transcript.)')
        preview_played = False
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
                        played = subprocess.run(['afplay', str(clip)], check=False)
                        preview_played = played.returncode == 0
                    else:
                        print('Audio preview unavailable; transcript examples remain available.')
        previous = prior.get(label, label)
        existing = previous.get('name', label) if isinstance(previous, dict) else previous
        answer = input(f'Name for {label} [{existing}]: ').strip()
        name = answer or existing
        if '\n' in name or '\r' in name or ':' in name:
            print('Names cannot contain colons or line breaks.', file=sys.stderr)
            return 2
        mapping[label] = name
        records[label] = {'name': name, 'confirmed_by': 'owner at prompt' if answer else 'previous mapping retained or unresolved', 'confirmed_at': datetime.now().astimezone().isoformat(timespec='seconds') if answer else 'not recorded', 'basis': 'owner-entered identity at existing prompt' if answer else 'not recorded', 'audio_preview_played': preview_played}
    print('\nProposed mapping:')
    for label, name in mapping.items():
        print(f'  {label} -> {name}')
    if input('Save named transcript and mapping? [y/N]: ').strip().lower() != 'y':
        print('Skipped. Existing files unchanged.')
        return 0
    # Generate from canonical JSON, never from the potentially modified review copy.
    def speaker_name(label):
        if label in mapping and mapping[label] != label:
            return mapping[label]
        if label in labels:
            return f'Speaker {chr(65 + labels.index(label))} (unidentified)'
        return 'Speaker unknown (unassigned)'
    def stamp(value):
        n = max(0, int(float(value)))
        return f'{n//3600:02d}:{(n//60)%60:02d}:{n%60:02d}'
    named = '\n'.join(f'[T+{stamp(seg.get("start", 0))}] {speaker_name(seg.get("speaker"))}: {str(seg.get("text", ""))}' for seg in segments) + '\n'
    target = run / 'transcript-named.txt'
    map_target = run / 'speaker-map.json'
    with tempfile.TemporaryDirectory(prefix='.speaker-write-', dir=run) as tmp:
        temp = Path(tmp)
        (temp / target.name).write_text(named, encoding='utf-8')
        (temp / map_target.name).write_text(json.dumps({'schema_version': 2, 'speakers': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
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
