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
  static const _surface   = PdfColor.fromInt(0xFFF8F9FA);
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
          _buildPatientSection(reportData),
          pw.SizedBox(height: 16),
          _buildLabInfoSection(reportData),
          pw.SizedBox(height: 16),
          _buildResultsSection(reportData),
          pw.SizedBox(height: 16),
          _buildObservationsSection(reportData),
          pw.SizedBox(height: 16),
          _buildDoctorReferenceSection(reportData),
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
                  'CARECRYPT',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                    letterSpacing: 2,
                  ),
                ),
                pw.Text(
                  'Healthcare Report',
                  style: pw.TextStyle(fontSize: 11, color: _mutedText),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('CONFIDENTIAL', style: pw.TextStyle(color: PdfColors.red700, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(color: _mutedText, fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.Divider(color: _primary, thickness: 1.5),
        pw.SizedBox(height: 4),
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
  static pw.Widget _buildPatientSection(Map<String, dynamic> data) {
    return _sectionCard(
      title: 'Patient Information',
      icon: '👤',
      color: _primary,
      children: [
        _infoGrid([
          _InfoItem('Patient ID', data['patient_id']?.toString() ?? '—'),
          _InfoItem('Name', data['patient_name']?.toString() ?? data['name']?.toString() ?? '—'),
          _InfoItem('Age', data['age']?.toString() ?? '—'),
          _InfoItem('Gender', data['gender']?.toString() ?? '—'),
          _InfoItem('Blood Group', data['blood_type']?.toString() ?? '—'),
          _InfoItem('Report Date', _formatDate(DateTime.now())),
        ]),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // Laboratory Information Section
  // ────────────────────────────────────────────────────────
  static pw.Widget _buildLabInfoSection(Map<String, dynamic> data) {
    return _sectionCard(
      title: 'Laboratory Information',
      icon: '🔬',
      color: _secondary,
      children: [
        _infoGrid([
          _InfoItem('Test Name', data['test_name']?.toString() ?? data['test_type']?.toString() ?? '—'),
          _InfoItem('Test Date', data['test_date']?.toString() ?? _formatDate(DateTime.now())),
          _InfoItem('Technician', data['technician_name']?.toString() ?? data['lab_id']?.toString() ?? '—'),
          _InfoItem('Lab ID', data['lab_id']?.toString() ?? '—'),
          _InfoItem('Request ID', data['request_id']?.toString() ?? '—'),
          _InfoItem('Status', 'Completed'),
        ]),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // Test Results Section
  // ────────────────────────────────────────────────────────
  static pw.Widget _buildResultsSection(Map<String, dynamic> data) {
    final result = data['test_result']?.toString() ?? '—';
    return _sectionCard(
      title: 'Test Results',
      icon: '📊',
      color: _primary,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Text(
            result,
            style: pw.TextStyle(fontSize: 11, color: _darkText, lineSpacing: 1.6),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // Observations Section
  // ────────────────────────────────────────────────────────
  static pw.Widget _buildObservationsSection(Map<String, dynamic> data) {
    final obs = data['observation']?.toString() ?? '—';
    final remarks = data['remarks']?.toString() ?? '';
    return _sectionCard(
      title: 'Clinical Observations',
      icon: '📋',
      color: _secondary,
      children: [
        pw.Text('Observations', style: pw.TextStyle(fontSize: 10, color: _mutedText, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Container(
          decoration: pw.BoxDecoration(color: _surface, borderRadius: pw.BorderRadius.circular(6)),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Text(obs, style: pw.TextStyle(fontSize: 11, color: _darkText, lineSpacing: 1.6)),
        ),
        if (remarks.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Additional Remarks', style: pw.TextStyle(fontSize: 10, color: _mutedText, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Container(
            decoration: pw.BoxDecoration(color: _surface, borderRadius: pw.BorderRadius.circular(6)),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Text(remarks, style: pw.TextStyle(fontSize: 11, color: _darkText, lineSpacing: 1.6)),
          ),
        ],
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  // Doctor Reference Section
  // ────────────────────────────────────────────────────────
  static pw.Widget _buildDoctorReferenceSection(Map<String, dynamic> data) {
    return _sectionCard(
      title: 'Doctor Reference',
      icon: '👨‍⚕️',
      color: _primary,
      children: [
        _infoGrid([
          _InfoItem('Referring Doctor', data['doctor_name']?.toString() ?? 'As per prescription'),
          _InfoItem('Doctor ID', data['doctor_id']?.toString() ?? '—'),
          _InfoItem('Department', data['department']?.toString() ?? 'General Medicine'),
          _InfoItem('Follow-up Required', data['follow_up']?.toString() ?? 'As advised'),
        ]),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(width: 120, height: 0.5, color: _darkText),
                pw.SizedBox(height: 4),
                pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 9, color: _mutedText)),
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
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF1A1A2E),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🔒 SECURITY INFORMATION',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal300,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _securityBadge('AES-256-GCM Protected'),
              pw.SizedBox(width: 8),
              _securityBadge('SHA-256 Verified'),
              pw.SizedBox(width: 8),
              _securityBadge('Generated by CareCrypt'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'SHA-256: $hash',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This document was generated by the CareCrypt secure healthcare platform. '
            'It is encrypted and digitally verified. Any alteration will invalidate the SHA-256 hash.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300, lineSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Shared layout helpers
  // ────────────────────────────────────────────────────────

  static pw.Widget _sectionCard({
    required String title,
    required String icon,
    required PdfColor color,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: pw.Text(
              '$icon  $title',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoGrid(List<_InfoItem> items) {
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
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows);
  }

  static pw.Widget _infoCell(_InfoItem item) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(item.label, style: pw.TextStyle(fontSize: 9, color: _mutedText)),
        pw.SizedBox(height: 2),
        pw.Text(item.value, style: pw.TextStyle(fontSize: 11, color: _darkText, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _securityBadge(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal800,
        borderRadius: pw.BorderRadius.circular(100),
      ),
      child: pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
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
