import 'package:calamansi_care/data/diagnosis_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Report paths use safe farmer folders and opaque stable IDs', () {
    final path = reportImageStoragePath('Maria Santos', 'device-secret-123');
    expect(path,
        matches(RegExp(r'^reports/maria-santos/report-[a-f0-9]{64}\.webp$')));
    expect(path, isNot(contains('device-secret')));
    expect(path, reportImageStoragePath('Maria Santos', 'device-secret-123'));
    expect(path, isNot(reportImageStoragePath('Maria Santos', 'other-report')));
    expect(reportImageStoragePath('../', 'id'), startsWith('reports/farmer/'));
    expect(reportImageStoragePath('a' * 100, 'id').split('/')[1].length, 64);
  });
}
