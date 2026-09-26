import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'export_report.dart';

/// Phase 3 (export overhaul): renders the compiled [CaseReport] to a
/// formatted PDF. Same document the Markdown renderer walks — the DB
/// already stripped everything the caller can't see, the client only
/// renders.
extension CaseReportPdf on CaseReport {
  Future<List<int>> toPdfBytes() async {
    final doc = pw.Document();
    final room = document['room'] as Map<String, dynamic>;

    pw.Widget section(String title, pw.Widget body) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 2, text: title, textStyle: pw.TextStyle(fontSize: 14)),
        body,
        pw.SizedBox(height: 12),
      ],
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Case Report — $roomName',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            'Generated ${generatedAt.toLocal()} by CaseThread',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Case type: ${room['case_type']}  ·  '
            'Status: ${room['status']}  ·  '
            'Opened: ${room['opened']}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          section(
            'Members',
            _listOrNone(
              (document['members'] as List? ?? []).map(
                (m) =>
                    '${(m as Map<String, dynamic>)['name']} '
                    '(${m['role']})',
              ),
            ),
          ),
          section(
            'Evidence',
            _listOrNone(
              (document['evidence'] as List? ?? []).map(
                (e) =>
                    '${(e as Map<String, dynamic>)['filename']} '
                    '(v${e['version']}, sha256 ${e['sha256']})',
              ),
            ),
          ),
          section(
            'Tasks',
            _listOrNone(
              (document['tasks'] as List? ?? []).map((t) {
                final tm = t as Map<String, dynamic>;
                final due = tm['due'] == null ? '' : ' — due ${tm['due']}';
                return '[${tm['status']}] ${tm['title']}$due';
              }),
            ),
          ),
          section(
            'Timeline',
            _listOrNone(
              (document['timeline'] as List? ?? []).map((e) {
                final em = e as Map<String, dynamic>;
                final payload = em['payload'] as Map<String, dynamic>?;
                final summary =
                    payload?['summary'] as String? ?? em['type'] as String;
                return '${em['when']} — ${em['actor'] ?? 'System'}: $summary';
              }),
            ),
          ),
          section(
            'Contradictions',
            _listOrNone(
              (document['contradictions'] as List? ?? []).map(
                (c) =>
                    '[${(c as Map<String, dynamic>)['status']}] ${c['detail']} '
                    '(flagged: ${c['flagged_reason']})',
              ),
            ),
          ),
          section(
            'Alibis',
            _listOrNone(
              (document['alibis'] as List? ?? []).map(
                (a) =>
                    '[${(a as Map<String, dynamic>)['status']}] ${a['claim']} '
                    '(window: ${a['window_start']} – ${a['window_end']})',
              ),
            ),
          ),
          section(
            'Investigation Gaps',
            _listOrNone(
              (document['gaps'] as List? ?? []).map(
                (g) =>
                    '[${(g as Map<String, dynamic>)['status']}] '
                    '${g['description']} (type: ${g['gap_type']})',
              ),
            ),
          ),
          if (document['investigation_status'] != null)
            pw.Text(
              'Investigation status: '
                  '${document['investigation_status']}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _listOrNone(Iterable<String> items) {
    final list = items.toList(growable: false);
    if (list.isEmpty) {
      return pw.Text('— none —', style: const pw.TextStyle(fontSize: 10));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in list)
          pw.Bullet(text: item, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }
}
