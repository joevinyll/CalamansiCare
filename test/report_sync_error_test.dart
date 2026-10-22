import 'package:calamansi_care/data/diagnosis_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Missing batch migration is reported as setup, not offline', () {
    final message = reportSyncErrorMessage(const PostgrestException(
        message: 'Missing function', code: 'PGRST202'));
    expect(message, contains('migration'));
    expect(message, isNot(contains('Waiting for internet')));
  });
  test('Upload and email failures have actionable messages', () {
    expect(
        reportSyncErrorMessage(
            const StorageException('Rejected', statusCode: '403')),
        contains('storage policies'));
    expect(reportSyncErrorMessage(const FunctionException(status: 400)),
        contains('send-report-email'));
  });
}
