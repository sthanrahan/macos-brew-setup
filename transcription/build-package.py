#!/usr/bin/env python3
"""Non-interactive, backwards-compatible package builder for completed WhisperX runs."""
import argparse
import csv
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path


def read_json(path):
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clock(seconds):
    n = max(0, int(float(seconds)))
    return f'{n // 3600:02d}:{(n // 60) % 60:02d}:{n % 60:02d}'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    run = args.run.expanduser().resolve()
    raw = sorted((run / 'raw').glob('*.json'))
    source = run / 'diarized.json' if (run / 'diarized.json').is_file() else (raw[0] if len(raw) == 1 else None)
    if source is None:
        parser.error('Expected diarized.json or exactly one raw/*.json')
    data = read_json(source)
    segments = data.get('segments')
    if not isinstance(segments, list):
        parser.error('Source JSON has no segments list')
    meta = read_json(run / 'run.json')
    diar = read_json(run / 'diarization.json')
    smap = read_json(run / 'speaker-map.json')
    speakers = smap.get('speakers', {})
    labels = sorted({s.get('speaker') for s in segments if re.fullmatch(r'SPEAKER_\d+', str(s.get('speaker', '')))})
    letters = {label: f'Speaker {chr(65 + i)} (unidentified)' for i, label in enumerate(labels)}

    def name(label):
        if label not in letters:
            return 'Speaker unknown (unassigned)'
        entry = speakers.get(label, {})
        value = entry.get('name', '') if isinstance(entry, dict) else entry
        if not isinstance(value, str) or not value.strip() or value.strip() == label:
            return letters[label]
        return value.strip()

    stem = re.sub(r'[^\w. -]+', '_', str(meta.get('input', source.stem)).split('/')[-1].rsplit('.', 1)[0]).strip(' .')
    run_date = re.search(r'\d{8}', run.name)
    prefix = run_date.group(0) if run_date else 'date-not-recorded'
    stem = f'{prefix}_{stem or "recording"}'
    out = run / 'package'
    out.mkdir(exist_ok=True)
    rows = []
    for i, seg in enumerate(segments, 1):
        label = seg.get('speaker', 'SPEAKER_UNKNOWN')
        rows.append(dict(index=i, start_seconds=seg.get('start', ''), end_seconds=seg.get('end', ''),
                         T_plus_display='T+' + clock(seg.get('start', 0)), whisperx_label=label,
                         name_or_letter=name(label), text=str(seg.get('text', ''))))
    header = [f'# Transcript — {stem}', '', 'Status: INTERNAL',
              f'Canonical source: {source.name} (SHA-256: {digest(source)})',
              f'Recording start: {meta.get("recording_start", "unknown")}',
              f'Recording start source: {meta.get("recording_start_source", "not recorded")}',
              f'Unverified recording-start candidates: {json.dumps(meta.get("recording_start_candidates", {}), ensure_ascii=False)}',
              f'Transcribed coverage: T+{clock(max((float(s.get("end", 0)) for s in segments), default=0))} (not verified recording duration)',
              f'Audio verification: {"Full transcript not audio-verified; speaker previews are not full verification."}',
              f'Speakers: {"; ".join(f"{label} = {name(label)}" for label in labels)}', '', '## Verbatim segments', '']
    transcript_lines = [f'[{r["T_plus_display"]}] {r["name_or_letter"]}: {r["text"]}' for r in rows]
    transcript = '\n'.join(header + transcript_lines) + '\n'
    csvbuf = io.StringIO(newline='')
    fields = ['index', 'start_seconds', 'end_seconds', 'T_plus_display', 'whisperx_label', 'name_or_letter', 'text']
    writer = csv.DictWriter(csvbuf, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)
    map_lines = ['# Speaker map', '', '| WhisperX label | Name | Confirmation basis | Audio preview played | Segments | First appears |', '|---|---|---|---|---:|---|']
    for label in labels:
        entry = speakers.get(label, {})
        if not isinstance(entry, dict):
            entry = {'name': entry}
        matches = [r for r in rows if r['whisperx_label'] == label]
        first = f'#{matches[0]["index"]}, {matches[0]["T_plus_display"]}' if matches else 'not recorded'
        map_lines.append(f'| {label} | {name(label)} | {entry.get("basis", "not recorded")} | {entry.get("audio_preview_played", "not recorded")} | {len(matches)} | {first} |')
    notes = ['# SOURCE NOTE', '', f'Canonical source: {source}', f'SHA-256: {digest(source)}',
             f'Number of segments: {len(rows)}', 'Audio verification: full transcript not verified against audio.',
             'Recording start candidates are unverified; do not treat them as event start.', '',
             '## Run metadata', '```json', json.dumps(meta, ensure_ascii=False, indent=2), '```',
             '## Diarisation metadata', '```json', json.dumps(diar or {'status': 'not recorded'}, ensure_ascii=False, indent=2), '```',
             '## Repetition audit', '```json', json.dumps(read_json(run / 'repetition-audit.json') or {'status': 'not recorded'}, ensure_ascii=False, indent=2), '```',
             '## Timing observations']
    for a, b in zip(rows, rows[1:]):
        try:
            if float(b['start_seconds']) < float(a['end_seconds']):
                notes.append(f'Overlap: #{a["index"]} and #{b["index"]} at {b["T_plus_display"]}')
        except (ValueError, TypeError):
            pass
    notes += ['', 'Word-level scores, where present, remain in the canonical raw JSON. No aggregate confidence is inferred.']
    paths = {
        f'{stem}_Transcript.md': transcript,
        f'{stem}_Speaker_Map.md': '\n'.join(map_lines) + '\n',
        f'{stem}_SOURCE_NOTE.md': '\n'.join(notes) + '\n',
        f'{stem}_Segments.csv': csvbuf.getvalue(),
    }
    # Verify exact text preservation before writing a distributable package.
    parsed = list(csv.DictReader(io.StringIO(paths[f'{stem}_Segments.csv'])))
    assert len(parsed) == len(rows) == len(transcript_lines)
    for i, (segment, row, line) in enumerate(zip(segments, parsed, transcript_lines)):
        assert row['text'] == str(segment.get('text', '')), f'CSV mismatch at #{i+1}'
        assert line == f'[{row["T_plus_display"]}] {row["name_or_letter"]}: {row["text"]}', f'Transcript mismatch at #{i+1}'
    for filename, content in paths.items():
        (out / filename).write_text(content, encoding='utf-8')
    manifest = out / 'manifest.sha256'
    manifest.write_text(''.join(f'{digest(out / filename)}  {filename}\n' for filename in paths), encoding='utf-8')
    archive = out / f'{stem}_WhisperX_Package.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
        for filename in [*paths, manifest.name]:
            z.write(out / filename, arcname=filename)
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert len(z.namelist()) == 5
    print(f'PACKAGE VALID: {len(rows)} segments; 4 files plus manifest; {archive}')


if __name__ == '__main__':
    main()
