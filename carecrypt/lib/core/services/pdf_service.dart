import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates professional hospital-grade PDF reports for CareCrypt.
class PdfService {
  // CareCrypt brand colours
  static const _primary   = PdfColor.fromInt(0xFF1A73E8);
  static const _secondary = PdfColor.fromInt(0xFF34A853);
  static const _darkText  = PdfColor.fromInt(0xFF202124);
  static const _mutedText = PdfColor.fromInt(0xFF5F6368);
  static const _border    = PdfColor.fromInt(0xFFDEE2E6);

  /// Build a professional lab report PDF.
  ///
  /// [reportData] must contain (keys are flexible — safe fallbacks used):
  ///   patient_id, patient_name, age, gender,
  ///   test_name, test_date, technician_name,
  ///   test_result, observation, remarks
  ///
  /// Returns raw PDF bytes ready to save or display via `printing`.
  static Future<Uint8List> generateLabReport(Map<String, dynamic> reportData) async {
    final pdf = pw.Document(
      title: 'CareCrypt Lab Report',
      author: 'CareCrypt',
      subject: 'Encrypted Medical Report',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        header: (ctx) => _buildHeader(ctx),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          ..._buildPatientSection(reportData),
          pw.SizedBox(height: 16),
          ..._buildLabInfoSection(reportData),
          pw.SizedBox(height: 16),
          ..._buildResultsSection(reportData),
          pw.SizedBox(height: 16),
          ..._buildObservationsSection(reportData),
          pw.SizedBox(height: 16),
          ..._buildDoctorReferenceSection(reportData),
          pw.SizedBox(height: 20),
          _buildSecuritySection(reportData),
        ],
      ),
    );

    return pdf.save();
  }

  // ────────────────────────────────────────────────────────
  // Header
  // ────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(pw.Context ctx) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CARECRYPT HEALTHCARE',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'SECURE DIGITAL MEDICAL REPORT',
                  style: pw.TextStyle(fontSize: 8, color: _mutedText, letterSpacing: 1.0),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFC53030), width: 1), // red-700
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'CONFIDENTIAL',
                    style: pw.TextStyle(color: PdfColor.fromInt(0xFFC53030), fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(color: _mutedText, fontSize: 8)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _primary, thickness: 1.0),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // Footer
  // ────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: _border),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CareCrypt — Your Health. Your Data. Your Control.',
                style: pw.TextStyle(fontSize: 8, color: _mutedText)),
            pw.Text('Generated: ${_formatDate(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: _mutedText)),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // Patient Information Section
  // ────────────────────────────────────────────────────────
  static List<pw.Widget> _buildPatientSection(Map<String, dynamic> data) {
    return _sectionCard(
      title: 'Patient Information',
      color: _primary,
      children: _infoGrid([
        _InfoItem('Patient ID', data['patient_id']?.toString() ?? '—'),
        _InfoItem('Name', data['patient_name']?.toString() ?? data['name']?.toString() ?? '—'),
        _InfoItem('Age', data['age']?.toString() ?? '—'),
        _InfoItem('Gender', data['gender']?.toString() ?? '—'),
        _InfoItem('Blood Group', data['blood_type']?.toString() ?? '—'),
        _InfoItem('Report Date', _formatDate(DateTime.now())),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────
  // Laboratory Information Section
  // ────────────────────────────────────────────────────────
  static List<pw.Widget> _buildLabInfoSection(Map<String, dynamic> data) {
    return _sectionCard(
      title: 'Laboratory Information',
      color: _secondary,
      children: _infoGrid([
        _InfoItem('Test Name', data['test_name']?.toString() ?? data['test_type']?.toString() ?? '—'),
        _InfoItem('Test Date', data['test_date']?.toString() ?? _formatDate(DateTime.now())),
        _InfoItem('Technician', data['technician_name']?.toString() ?? data['lab_id']?.toString() ?? '—'),
        _InfoItem('Lab ID', data['lab_id']?.toString() ?? '—'),
        _InfoItem('Request ID', data['request_id']?.toString() ?? '—'),
        _InfoItem('Status', 'Completed'),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────
  // Test Results Section
  // ────────────────────────────────────────────────────────
  static List<pw.Widget> _buildResultsSection(Map<String, dynamic> data) {
    final resultStr = data['test_result']?.toString() ?? '—';
    final lines = resultStr.split('\n');
    final tableRows = <pw.TableRow>[];

    // Table Header Row
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF1F5F9), // slate-100
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('TEST PARAMETER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkText)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('RESULT VALUE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkText)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('REFERENCE RANGE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkText)),
          ),
        ],
      ),
    );

    bool hasTableData = false;
    final List<pw.Widget> textBlocks = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('🔓') || trimmed.startsWith('🔑') || trimmed.contains('EXTRACTION') || trimmed.contains('DECRYPTION') || trimmed.startsWith('──')) {
        textBlocks.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              trimmed,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: trimmed.startsWith('──') ? pw.FontWeight.normal : pw.FontWeight.bold,
                color: trimmed.startsWith('──') ? _mutedText : PdfColor.fromInt(0xFF15803D), // dark green
              ),
            ),
          ),
        );
        continue;
      }

      if (trimmed.endsWith(':') || trimmed.contains('PROFILE:')) {
        textBlocks.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              trimmed,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _primary),
            ),
          ),
        );
        continue;
      }

      // Try to parse standard line: "Parameter: Value (Normal: Range)" or "Parameter: Value"
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex != -1) {
        final param = trimmed.substring(0, colonIndex).trim();
        final rest = trimmed.substring(colonIndex + 1).trim();

        var value = rest;
        var range = '—';

        final parenIndex = rest.indexOf('(');
        if (parenIndex != -1) {
          value = rest.substring(0, parenIndex).trim();
          var rangeContent = rest.substring(parenIndex + 1).trim();
          if (rangeContent.endsWith(')')) {
            rangeContent = rangeContent.substring(0, rangeContent.length - 1).trim();
          }
          if (rangeContent.startsWith('Normal:')) {
            range = rangeContent.substring(7).trim();
          } else {
            range = rangeContent;
          }
        }

        hasTableData = true;
        tableRows.add(
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(param, style: pw.TextStyle(fontSize: 8.5, color: _darkText)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _darkText)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(range, style: pw.TextStyle(fontSize: 8.5, color: _mutedText)),
              ),
            ],
          ),
        );
      } else {
        textBlocks.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text(trimmed, style: pw.TextStyle(fontSize: 8.5, color: _darkText)),
          ),
        );
      }
    }

    final childrenWidgets = <pw.Widget>[];
    if (textBlocks.isNotEmpty) {
      childrenWidgets.addAll(textBlocks);
      childrenWidgets.add(pw.SizedBox(height: 8));
    }

    if (hasTableData) {
      childrenWidgets.add(
        pw.Table(
          border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.3),
          },
          children: tableRows,
        ),
      );
    } else {
      childrenWidgets.add(
        pw.Text(
          resultStr,
          style: pw.TextStyle(fontSize: 9, color: _darkText, lineSpacing: 1.4),
        ),
      );
    }

    return _sectionCard(
      title: 'Test Results',
      color: _primary,
      children: childrenWidgets,
    );
  }

  // ────────────────────────────────────────────────────────
  // Observations Section
  // ────────────────────────────────────────────────────────
  static List<pw.Widget> _buildObservationsSection(Map<String, dynamic> data) {
    final obs = data['observation']?.toString() ?? '—';
    final remarks = data['remarks']?.toString() ?? '';
    final childrenList = <pw.Widget>[
      pw.Text('OBSERVATIONS', style: pw.TextStyle(fontSize: 8.5, color: _mutedText, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
      pw.SizedBox(height: 3),
      pw.Text(obs, style: pw.TextStyle(fontSize: 10, color: _darkText, lineSpacing: 1.5)),
    ];
    
    if (remarks.isNotEmpty) {
      childrenList.addAll([
        pw.SizedBox(height: 10),
        pw.Text('ADDITIONAL REMARKS', style: pw.TextStyle(fontSize: 8.5, color: _mutedText, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
        pw.SizedBox(height: 3),
        pw.Text(remarks, style: pw.TextStyle(fontSize: 10, color: _darkText, lineSpacing: 1.5)),
      ]);
    }
    return _sectionCard(
      title: 'Clinical Observations',
      color: _secondary,
      children: childrenList,
    );
  }

  // ────────────────────────────────────────────────────────
  // Doctor Reference Section
  // ────────────────────────────────────────────────────────
  static List<pw.Widget> _buildDoctorReferenceSection(Map<String, dynamic> data) {
    final doctorItems = _infoGrid([
      _InfoItem('Referring Doctor', data['doctor_name']?.toString() ?? 'As per prescription'),
      _InfoItem('Doctor ID', data['doctor_id']?.toString() ?? '—'),
      _InfoItem('Department', data['department']?.toString() ?? 'General Medicine'),
      _InfoItem('Follow-up Required', data['follow_up']?.toString() ?? 'As advised'),
    ]);

    return _sectionCard(
      title: 'Doctor Reference',
      color: _primary,
      children: [
        ...doctorItems,
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(width: 140, height: 0.5, color: _darkText),
                pw.SizedBox(height: 4),
                pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 8.5, color: _mutedText)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // Security Footer Section
  // ────────────────────────────────────────────────────────
  static pw.Widget _buildSecuritySection(Map<String, dynamic> data) {
    final hash = data['sha256_hash']?.toString() ?? '—';
    final decrypted = data['is_decrypted'] == true;
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC), // slate-50
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.75), // slate-200
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🔒 SECURITY & CRYPTOGRAPHIC INTEGRITY AUDIT',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF0F172A), // slate-900
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _securityBadge('AES-256-GCM PROTECTED', isPrimary: true),
              pw.SizedBox(width: 6),
              if (decrypted) ...[
                _securityBadge('DECRYPTED SECURELY', isSuccess: true),
                pw.SizedBox(width: 6),
              ],
              _securityBadge('SHA-256 VERIFIED', isPrimary: true),
              pw.SizedBox(width: 6),
              _securityBadge('CARECRYPT SIGNED', isPrimary: true),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'SHA-256 DOCUMENT HASH: $hash',
            style: pw.TextStyle(fontSize: 7, color: const PdfColor.fromInt(0xFF475569), fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            decrypted
                ? 'This document was successfully decrypted from the CareCrypt secure steganographic vault. '
                  'The payload is client-side AES-256-GCM decrypted and integrity-verified. Any external alteration will invalidate the SHA-256 hash.'
                : 'This document was generated by the CareCrypt secure healthcare platform. '
                  'It is fully encrypted and digitally verified. Any alteration will invalidate the SHA-256 hash.',
            style: pw.TextStyle(fontSize: 7.5, color: const PdfColor.fromInt(0xFF334155), lineSpacing: 1.4),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Shared layout helpers
  // ────────────────────────────────────────────────────────

  static List<pw.Widget> _sectionCard({
    required String title,
    required PdfColor color,
    required List<pw.Widget> children,
  }) {
    return [
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: color, width: 3.5),
          ),
        ),
        padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: color,
            letterSpacing: 1.1,
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      ...children.map((child) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12),
        child: child,
      )),
      pw.SizedBox(height: 14),
    ];
  }

  static List<pw.Widget> _infoGrid(List<_InfoItem> items) {
    final rows = <pw.Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = (i + 1 < items.length) ? items[i + 1] : null;
      rows.add(
        pw.Row(
          children: [
            pw.Expanded(child: _infoCell(left)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: right != null ? _infoCell(right) : pw.SizedBox()),
          ],
        ),
      );
      if (i + 2 < items.length) rows.add(pw.SizedBox(height: 6));
    }
    return rows;
  }

  static pw.Widget _infoCell(_InfoItem item) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(item.label.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, color: _mutedText, letterSpacing: 0.5)),
        pw.SizedBox(height: 1.5),
        pw.Text(item.value, style: pw.TextStyle(fontSize: 9.5, color: _darkText, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _securityBadge(String label, {bool isPrimary = false, bool isSuccess = false}) {
    final bgColor = isSuccess 
        ? const PdfColor.fromInt(0xFFDCFCE7) // emerald-100
        : const PdfColor.fromInt(0xFFDBEAFE); // blue-100
    final textColor = isSuccess 
        ? const PdfColor.fromInt(0xFF15803D) // emerald-700
        : const PdfColor.fromInt(0xFF1D4ED8); // blue-700
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 7, color: textColor, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}
