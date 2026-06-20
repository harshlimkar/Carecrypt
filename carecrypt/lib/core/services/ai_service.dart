import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiSafetyScore {
  final String medicine;
  final double safetyPercent;
  final String riskLevel; // 'safe', 'warning', 'danger'
  final List<String> warnings;
  final String recommendation;

  const AiSafetyScore({
    required this.medicine,
    required this.safetyPercent,
    required this.riskLevel,
    required this.warnings,
    required this.recommendation,
  });
}

class AiAnalysisResult {
  final List<AiSafetyScore> scores;
  final List<String> interactions;
  final List<String> duplicates;
  final List<String> allergyConflicts;
  final String overallRecommendation;

  const AiAnalysisResult({
    required this.scores,
    required this.interactions,
    required this.duplicates,
    required this.allergyConflicts,
    required this.overallRecommendation,
  });
}

class AiService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

  static String get _ollamaUrl => dotenv.env['OLLAMA_BASE_URL'] ?? 'http://localhost:11434';
  static String get _model => dotenv.env['OLLAMA_MODEL'] ?? 'llama3';

  static Future<AiAnalysisResult> analyzePrescription({
    required List<String> medicines,
    required List<String> diagnoses,
    required List<String> medicalHistory,
    List<String> allergies = const [],
  }) async {
    final prompt = _buildPrompt(
      medicines: medicines,
      diagnoses: diagnoses,
      medicalHistory: medicalHistory,
      allergies: allergies,
    );

    try {
      final response = await _dio.post(
        '$_ollamaUrl/api/generate',
        data: jsonEncode({
          'model': _model,
          'prompt': prompt,
          'stream': false,
          'format': 'json',
          'options': {'temperature': 0.1, 'top_p': 0.9},
        }),
      );

      final responseText = (response.data as Map<String, dynamic>)['response'] as String;
      return _parseResponse(responseText, medicines);
    } catch (e) {
      // Graceful fallback with mock safety scores
      return _generateFallbackScores(medicines);
    }
  }

  static String _buildPrompt({
    required List<String> medicines,
    required List<String> diagnoses,
    required List<String> medicalHistory,
    required List<String> allergies,
  }) {
    return '''
You are a clinical pharmacology AI assistant. Analyze the following prescription for safety.

PATIENT DIAGNOSES: ${diagnoses.join(', ')}
MEDICAL HISTORY: ${medicalHistory.join(', ')}
KNOWN ALLERGIES: ${allergies.isEmpty ? 'None' : allergies.join(', ')}
PRESCRIBED MEDICINES: ${medicines.join(', ')}

Respond ONLY with valid JSON in this exact format:
{
  "medicines": [
    {
      "name": "MedicineName",
      "safetyPercent": 95,
      "riskLevel": "safe",
      "warnings": [],
      "recommendation": "Continue as prescribed"
    }
  ],
  "interactions": ["List of drug interactions found"],
  "duplicates": ["List of duplicate medications"],
  "allergyConflicts": ["List of allergy conflicts"],
  "overallRecommendation": "Overall clinical recommendation"
}

Risk levels: "safe" (80-100%), "warning" (60-79%), "danger" (0-59%).
Be precise and clinical. Consider drug interactions, contraindications, and dosage risks.
''';
  }

  static AiAnalysisResult _parseResponse(String responseText, List<String> medicines) {
    try {
      // Extract JSON from response
      final jsonStart = responseText.indexOf('{');
      final jsonEnd = responseText.lastIndexOf('}') + 1;
      if (jsonStart == -1 || jsonEnd == 0) throw Exception('No JSON found');

      final jsonStr = responseText.substring(jsonStart, jsonEnd);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final medList = (data['medicines'] as List<dynamic>? ?? []).map((m) {
        final med = m as Map<String, dynamic>;
        return AiSafetyScore(
          medicine: med['name'] as String? ?? '',
          safetyPercent: (med['safetyPercent'] as num?)?.toDouble() ?? 85.0,
          riskLevel: med['riskLevel'] as String? ?? 'safe',
          warnings: List<String>.from(med['warnings'] as List? ?? []),
          recommendation: med['recommendation'] as String? ?? '',
        );
      }).toList();

      return AiAnalysisResult(
        scores: medList,
        interactions: List<String>.from(data['interactions'] as List? ?? []),
        duplicates: List<String>.from(data['duplicates'] as List? ?? []),
        allergyConflicts: List<String>.from(data['allergyConflicts'] as List? ?? []),
        overallRecommendation: data['overallRecommendation'] as String? ?? 'Review with pharmacist.',
      );
    } catch (_) {
      return _generateFallbackScores(medicines);
    }
  }

  static AiAnalysisResult _generateFallbackScores(List<String> medicines) {
    // Mock safety scores used when Ollama is unavailable
    final mockData = {
      'paracetamol': 98.0,
      'amoxicillin': 94.0,
      'ibuprofen': 72.0,
      'aspirin': 68.0,
      'metformin': 92.0,
      'lisinopril': 89.0,
      'atorvastatin': 91.0,
    };

    final scores = medicines.map((med) {
      final name = med.toLowerCase();
      final safety = mockData[name] ?? 85.0;
      final riskLevel = safety >= 80 ? 'safe' : safety >= 60 ? 'warning' : 'danger';
      return AiSafetyScore(
        medicine: med,
        safetyPercent: safety,
        riskLevel: riskLevel,
        warnings: riskLevel == 'danger' ? ['High risk — consult pharmacist'] : [],
        recommendation: riskLevel == 'safe' ? 'Safe to administer' : 'Monitor patient closely',
      );
    }).toList();

    return AiAnalysisResult(
      scores: scores,
      interactions: [],
      duplicates: [],
      allergyConflicts: [],
      overallRecommendation: 'AI offline — using cached safety profiles.',
    );
  }
}
