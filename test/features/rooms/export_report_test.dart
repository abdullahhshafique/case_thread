import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/rooms/export_pdf.dart';
import 'package:case_thread/features/rooms/export_report.dart';

CaseReport _report() => CaseReport(document: {
  'room': {
    'name': 'Riverside Robbery #2291',
    'case_type': 'legal',
    'status': 'active',
    'opened': '10 September 2026',
  },
  'generated_at': '2026-09-24T10:00:00Z',
  'investigation_status': 'under_investigation',
  'members': [
    {'name': 'Alice', 'role': 'lead_investigator'},
    {'name': 'Bob', 'role': 'analyst'},
  ],
  'evidence': [
    {
      'filename': 'cctv-still.png',
      'version': 1,
      'sha256': 'abc123',
    },
  ],
  'tasks': [
    {'title': 'Interview witness', 'status': 'open', 'due': '2026-09-30'},
  ],
  'timeline': [
    {
      'when': '2026-09-12',
      'actor': 'Alice',
      'type': 'note',
      'payload': {'summary': 'Reviewed CCTV footage'},
    },
  ],
  'contradictions': [
    {
      'status': 'open',
      'detail': 'Witness A vs Witness B on arrival time',
      'flagged_reason': 'statement_conflict',
    },
  ],
  'alibis': [
    {
      'status': 'conflict',
      'claim': 'At home',
      'window_start': '2026-09-10T20:00:00Z',
      'window_end': '2026-09-10T23:00:00Z',
    },
  ],
  'gaps': [
    {
      'status': 'open',
      'description': 'Missing phone records',
      'gap_type': 'evidence',
    },
  ],
});

void main() {
  test('toMarkdown renders all sections of the compiled report', () {
    final md = _report().toMarkdown();

    expect(md, contains('# Case Report — Riverside Robbery #2291'));
    expect(md, contains('## Members'));
    expect(md, contains('- Alice (lead_investigator)'));
    expect(md, contains('## Evidence'));
    expect(md, contains('cctv-still.png (v1, sha256 `abc123`)'));
    expect(md, contains('## Tasks'));
    expect(md, contains('[open] Interview witness — due 2026-09-30'));
    expect(md, contains('## Timeline'));
    expect(md, contains('Reviewed CCTV footage'));
    expect(md, contains('## Contradictions'));
    expect(md, contains('[open] Witness A vs Witness B on arrival time'));
    expect(md, contains('## Alibis'));
    expect(md, contains('[conflict] At home'));
    expect(md, contains('## Investigation Gaps'));
    expect(md, contains('[open] Missing phone records'));
    expect(md, contains('**Investigation status:** under_investigation'));
  });

  test('toMarkdown omits empty sections honestly', () {
    final doc = Map<String, dynamic>.from(_report().document)
      ..['contradictions'] = []
      ..['alibis'] = []
      ..['gaps'] = [];
    final md = CaseReport(document: doc).toMarkdown();

    expect(md, contains('## Contradictions'));
    expect(md, isNot(contains('conflict')));
  });

  test('toPdfBytes produces a non-empty PDF document', () async {
    final bytes = await _report().toPdfBytes();

    expect(bytes, isNotEmpty);
    // PDF magic number: %PDF-
    final header = String.fromCharCodes(bytes.take(5));
    expect(header, '%PDF-');
  });

  test('toPdfBytes renders an empty report without throwing', () async {
    final empty = CaseReport(document: {
      'room': {
        'name': 'Empty case',
        'case_type': 'legal',
        'status': 'active',
        'opened': '1 September 2026',
      },
      'generated_at': '2026-09-24T10:00:00Z',
      'members': [],
      'evidence': [],
      'tasks': [],
      'timeline': [],
      'contradictions': [],
      'alibis': [],
      'gaps': [],
    });
    final bytes = await empty.toPdfBytes();

    expect(bytes, isNotEmpty);
  });
}
