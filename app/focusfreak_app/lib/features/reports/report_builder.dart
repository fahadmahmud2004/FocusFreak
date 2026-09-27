import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/ff_constants.dart';
import '../../core/ff_format.dart';
import '../../data/db/database.dart';
import '../../design/ff_colors.dart';
import '../../domain/engine/insight_engine.dart';
import '../../domain/engine/streak_engine.dart';
import '../../domain/model/session_state.dart';

/// Builds the PDF report.
///
/// Charts are drawn as PDF vector primitives rather than captured as images:
/// a screenshot of a dark-themed chart is unreadable on paper, and it would be
/// pinned to whatever device resolution generated it.
///
/// The report leads with the verified/claimed split and never omits a bad week.
/// Its purpose is to be evidence — a document that only showed good days would
/// not be worth printing.
class ReportBuilder {
  const ReportBuilder();

  static final PdfColor _ink = PdfColor.fromInt(0xFF16161A);
  static final PdfColor _muted = PdfColor.fromInt(0xFF6E6E7A);
  static final PdfColor _rule = PdfColor.fromInt(0xFFE0DCD2);
  static final PdfColor _verified = PdfColor.fromInt(0xFF12A05C);
  static final PdfColor _claimed = PdfColor.fromInt(0xFFC9C9D2);
  static final PdfColor _gold = PdfColor.fromInt(0xFF9A6E12);

  static PdfColor _category(int id) {
    final c = FfColors.category(id);
    return PdfColor(c.r, c.g, c.b);
  }

  Future<Uint8List> build({
    required String title,
    required DateTime from,
    required DateTime to,
    required List<DaySummary> days,
    required List<Session> sessions,
    required StreakResult streak,
    required List<Insight> insights,
    String owner = '',
  }) async {
    // Whose record this is. A report is something you hand to a supervisor,
    // and one with a name on it is a document rather than a printout.
    final who = _ascii(owner.trim());

    final doc = pw.Document(
      title: who.isEmpty ? '$title · FocusFreak' : '$title · $who',
      author: who.isEmpty ? 'FocusFreak' : who,
      creator: 'FocusFreak',
    );

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/logo/focusfreak_mark.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // A missing logo must not stop a report being produced.
    }

    final verified = days.fold(0, (s, d) => s + d.verifiedMin);
    final claimed = days.fold(0, (s, d) => s + d.claimedMin);
    final blocks = days.fold(0, (s, d) => s + d.blocksDone);
    final violations = days.fold(0, (s, d) => s + d.violations);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // The default cap is 20 pages, which an all-time report passes easily.
        maxPages: 200,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 48),
        header: (context) => context.pageNumber == 1
            ? _header(logo, title, from, to, who)
            : _runningHead(title, who),
        footer: (context) => _footer(context),
        build: (context) => <pw.Widget>[
          _summary(verified, claimed, blocks, violations, streak),
          pw.SizedBox(height: 22),
          if (insights.isNotEmpty) ...<pw.Widget>[
            _insights(insights),
            pw.SizedBox(height: 22),
          ],
          _dailyChart(days),
          pw.SizedBox(height: 22),
          _categoryTable(sessions),
          pw.SizedBox(height: 22),
          // Spread rather than nested: a pw.Column cannot be split across
          // pages in a MultiPage, so wrapping a long table in one makes the
          // layout unable to advance and it fails with TooManyPagesException.
          // Only the table itself knows how to break.
          ..._blockTable(sessions),
          if (violations > 0) ...<pw.Widget>[
            pw.SizedBox(height: 22),
            ..._violationNote(sessions),
          ],
          pw.SizedBox(height: 26),
          _methodology(),
        ],
      ),
    );

    return doc.save();
  }

  // --- page furniture -----------------------------------------------------------

  pw.Widget _header(
    pw.MemoryImage? logo,
    String title,
    DateTime from,
    DateTime to,
    String owner,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          if (logo != null)
            pw.Container(
              width: 34,
              height: 34,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(logo),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.Text(
                  FfDates.sameDay(from, to)
                      ? FfFormat.fullDate(from)
                      : '${FfFormat.fullDate(from)} to ${FfFormat.fullDate(to)}',
                  style: pw.TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                'FocusFreak',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _gold,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (owner.isNotEmpty)
                pw.Text(owner, style: pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Divider(color: _rule, height: 1),
      pw.SizedBox(height: 16),
    ],
  );

  pw.Widget _runningHead(String title, String owner) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Text(
      owner.isEmpty ? title : '$title - $owner',
      style: pw.TextStyle(fontSize: 9, color: _muted),
    ),
  );

  pw.Widget _footer(pw.Context context) => pw.Column(
    children: <pw.Widget>[
      pw.Divider(color: _rule, height: 1),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            'Generated ${FfFormat.fullDate(DateTime.now())} - '
            'all data stored on device',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    ],
  );

  // --- sections -------------------------------------------------------------------

  pw.Widget _summary(
    int verified,
    int claimed,
    int blocks,
    int violations,
    StreakResult streak,
  ) {
    final ratio = FfFormat.ratio(verified, claimed);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          children: <pw.Widget>[
            _tile(
              'Verified focus',
              FfFormat.minutes(verified),
              'of ${FfFormat.minutes(claimed)} claimed',
              _verified,
            ),
            _tile(
              'Verified share',
              FfFormat.percent(ratio),
              'of elapsed tracked time',
              _ink,
            ),
            _tile(
              'Blocks completed',
              '$blocks',
              '$violations interruption${violations == 1 ? '' : 's'}',
              _ink,
            ),
            _tile('Streak', '${streak.current}', 'best ${streak.best}', _ink),
          ],
        ),
      ],
    );
  }

  pw.Widget _tile(String label, String value, String note, PdfColor colour) =>
      pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 10),
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _rule),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                label.toUpperCase(),
                style: pw.TextStyle(fontSize: 7, color: _muted),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: colour,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(note, style: pw.TextStyle(fontSize: 7, color: _muted)),
            ],
          ),
        ),
      );

  pw.Widget _insights(List<Insight> insights) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFFAF6EC),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFE6D9B8)),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          'WHAT THE NUMBERS SAY',
          style: pw.TextStyle(fontSize: 7, color: _gold),
        ),
        pw.SizedBox(height: 7),
        for (final i in insights.take(4))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              '- ${_ascii(i.text)}',
              style: pw.TextStyle(fontSize: 9.5, color: _ink),
            ),
          ),
      ],
    ),
  );

  /// Past this many days, one bar per day is both unreadable on A4 and
  /// enormous in the output file. Longer ranges are bucketed into weeks.
  static const int _maxDailyBars = 35;

  pw.Widget _dailyChart(List<DaySummary> raw) {
    if (raw.isEmpty) return pw.SizedBox();

    final bucketed = raw.length > _maxDailyBars;
    final days = bucketed ? _bucketIntoWeeks(raw) : raw;

    final max = days
        .map((d) => d.claimedMin > d.verifiedMin ? d.claimedMin : d.verifiedMin)
        .fold(0, (a, b) => a > b ? a : b);
    final scale = max == 0 ? 1 : max;
    const chartHeight = 110.0;
    final labelEvery = (days.length / 10).ceil();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _sectionTitle(
          bucketed
              ? 'Verified against claimed, by week'
              : 'Verified against claimed, by day',
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'The pale bar is elapsed time in tracked blocks. The solid bar is the '
          'part that met every available verification check. The gap is the '
          'difference.',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
        pw.SizedBox(height: 10),
        pw.SizedBox(
          height: chartHeight,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              for (final d in days)
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(horizontal: 0.8),
                    child: pw.Stack(
                      alignment: pw.Alignment.bottomCenter,
                      children: <pw.Widget>[
                        pw.Container(
                          height: chartHeight * d.claimedMin / scale,
                          color: _claimed,
                        ),
                        pw.Container(
                          height: chartHeight * d.verifiedMin / scale,
                          color: _verified,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: <pw.Widget>[
            for (var i = 0; i < days.length; i++)
              pw.Expanded(
                child: pw.Text(
                  i % labelEvery == 0 ? FfFormat.shortDate(days[i].day) : '',
                  style: pw.TextStyle(fontSize: 5.5, color: _muted),
                  textAlign: pw.TextAlign.center,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          bucketed
              ? 'Best week: ${FfFormat.minutes(max)} claimed'
              : 'Peak day: ${FfFormat.minutes(max)}',
          style: pw.TextStyle(fontSize: 7, color: _muted),
        ),
      ],
    );
  }

  /// Sum consecutive days into Monday-anchored weeks.
  static List<DaySummary> _bucketIntoWeeks(List<DaySummary> days) {
    final buckets = <DateTime, DaySummary>{};
    for (final d in days) {
      final key = FfDates.startOfWeek(d.day);
      final existing = buckets[key];
      buckets[key] = DaySummary(
        day: key,
        verifiedMin: (existing?.verifiedMin ?? 0) + d.verifiedMin,
        claimedMin: (existing?.claimedMin ?? 0) + d.claimedMin,
        blocksDone: (existing?.blocksDone ?? 0) + d.blocksDone,
        blocksTotal: (existing?.blocksTotal ?? 0) + d.blocksTotal,
        violations: (existing?.violations ?? 0) + d.violations,
      );
    }
    final out = buckets.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return out;
  }

  pw.Widget _categoryTable(List<Session> sessions) {
    final byCategory = <int, int>{};
    for (final s in sessions) {
      byCategory.update(
        s.category,
        (v) => v + s.verifiedSec,
        ifAbsent: () => s.verifiedSec,
      );
    }
    final total = byCategory.values.fold(0, (a, b) => a + b);
    if (total == 0) return pw.SizedBox();

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        _sectionTitle('Verified time by category'),
        pw.SizedBox(height: 8),
        for (final e in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              children: <pw.Widget>[
                pw.Container(width: 8, height: 8, color: _category(e.key)),
                pw.SizedBox(width: 7),
                pw.SizedBox(
                  width: 110,
                  child: pw.Text(
                    FfCategory.fromId(e.key).label,
                    style: pw.TextStyle(fontSize: 9, color: _ink),
                  ),
                ),
                pw.Expanded(
                  // The pdf package has no FractionallySizedBox, so the bar is
                  // split into two flexed halves instead.
                  child: pw.Row(
                    children: <pw.Widget>[
                      pw.Expanded(
                        flex: (e.value * 1000 ~/ total).clamp(1, 1000),
                        child: pw.Container(height: 8, color: _category(e.key)),
                      ),
                      pw.Expanded(
                        flex: (1000 - e.value * 1000 ~/ total).clamp(1, 1000),
                        child: pw.Container(
                          height: 8,
                          color: PdfColor.fromInt(0xFFF1EEE7),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 54,
                  child: pw.Text(
                    FfFormat.minutes(e.value ~/ 60),
                    style: pw.TextStyle(fontSize: 9, color: _ink),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.SizedBox(
                  width: 32,
                  child: pw.Text(
                    FfFormat.percent(e.value / total),
                    style: pw.TextStyle(fontSize: 8, color: _muted),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// A full block table past this many rows produces a document nobody reads.
  /// The rows are capped and the omission is stated, rather than either
  /// failing to render or silently dropping the tail.
  static const int _maxTableRows = 250;

  List<pw.Widget> _blockTable(List<Session> sessions) {
    if (sessions.isEmpty) return const <pw.Widget>[];

    final shown = sessions.length > _maxTableRows
        ? sessions.sublist(sessions.length - _maxTableRows)
        : sessions;
    final omitted = sessions.length - shown.length;

    return <pw.Widget>[
      _sectionTitle(
        omitted == 0 ? 'Every block' : 'Blocks (most recent $_maxTableRows)',
      ),
      if (omitted > 0) ...<pw.Widget>[
        pw.SizedBox(height: 3),
        pw.Text(
          '$omitted earlier block${omitted == 1 ? '' : 's'} in this period '
          'are summarised above but not listed individually. Export CSV for '
          'the complete record.',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: const <String>[
          'Date',
          'Start',
          'Block',
          'Category',
          'Claimed',
          'Verified',
          'Evidence',
          'Interrupted',
        ],
        data: <List<String>>[
          for (final s in shown)
            <String>[
              FfFormat.shortDate(s.startedAt),
              FfFormat.wallClock(s.startedAt),
              _ascii(s.blockName),
              FfCategory.fromId(s.category).label,
              FfFormat.minutes(s.claimedSec ~/ 60),
              FfFormat.minutes(s.verifiedSec ~/ 60),
              Provenance.values[s.provenance].label,
              s.violations == 0 ? '-' : '${s.violations}',
            ],
        ],
        headerStyle: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
        headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1EEE7)),
        cellStyle: pw.TextStyle(fontSize: 7.5, color: _ink),
        cellHeight: 15,
        cellAlignments: <int, pw.Alignment>{
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerLeft,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerLeft,
          7: pw.Alignment.center,
        },
        border: pw.TableBorder.all(color: _rule, width: 0.5),
      ),
    ];
  }

  List<pw.Widget> _violationNote(List<Session> sessions) {
    final all = sessions.where((s) => s.violations > 0).toList();
    if (all.isEmpty) return const <pw.Widget>[];
    final interrupted = all.length > _maxTableRows
        ? all.sublist(all.length - _maxTableRows)
        : all;

    return <pw.Widget>[
      _sectionTitle('Interruptions'),
      pw.SizedBox(height: 4),
      pw.Text(
        'Blocks where a verification check dropped out. A short break inside '
        'the ${FfFirmware.graceRunning.inSeconds}-second grace window does '
        'not appear here.',
        style: pw.TextStyle(fontSize: 8, color: _muted),
      ),
      pw.SizedBox(height: 8),
      for (final s in interrupted)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            '${FfFormat.shortDate(s.startedAt)} '
            '${FfFormat.wallClock(s.startedAt)} - ${_ascii(s.blockName)} - '
            '${s.violations} interruption${s.violations == 1 ? '' : 's'}, '
            '${FfFormat.minutes((s.claimedSec - s.verifiedSec) ~/ 60)} '
            'unverified',
            style: pw.TextStyle(fontSize: 8.5, color: _ink),
          ),
        ),
    ];
  }

  /// How the numbers were produced.
  ///
  /// A report that claims "verified" without saying what was verified, by what,
  /// is exactly the unearned confidence this product exists to replace.
  pw.Widget _methodology() => pw.Container(
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _rule),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          'HOW THESE NUMBERS WERE PRODUCED',
          style: pw.TextStyle(fontSize: 7, color: _muted),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Claimed minutes are elapsed minutes inside a tracked block. '
          'Verified minutes are the subset where every available check held '
          'at once. Unverified time past '
          '${FfFirmware.graceRunning.inSeconds} seconds freezes the timer; '
          'past ${FfFirmware.gracePaused.inMinutes} minutes the block is '
          'recorded as broken.',
          style: pw.TextStyle(fontSize: 8.5, color: _ink),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'The Evidence column says which checks were available. '
          '"Sensor-verified" means a FocusFreak device confirmed you were '
          'at the desk with the phone docked. "App-verified" means the '
          'phone alone confirmed the screen stayed locked. It cannot know '
          'whether you were present. "Untracked" means the block ran as a '
          'plain timer. Checks with no sensor are excluded from the verdict '
          'rather than assumed.',
          style: pw.TextStyle(fontSize: 8.5, color: _ink),
        ),
      ],
    ),
  );

  /// Map typographic punctuation onto ASCII.
  ///
  /// The PDF uses the built-in Helvetica metrics, which have no glyphs for
  /// en/em dashes, curly quotes or the middle dot — they render as hollow
  /// boxes. Embedding a full Unicode font would fix this properly and is the
  /// right long-term answer; until then, substituting is better than printing
  /// boxes. Characters with no ASCII equivalent are left alone rather than
  /// silently deleted.
  static String _ascii(String v) => v
      .replaceAll('\u2014', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u00b7', '-')
      .replaceAll('\u2022', '-')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll('\u2026', '...')
      .replaceAll('\u00b0', ' deg');

  pw.Widget _sectionTitle(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  );
}
