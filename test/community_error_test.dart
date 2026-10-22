import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calamansi_care/data/community_repository.dart';

void main() {
  test(
      'Missing visibility column identifies a database migration, not internet',
      () {
    const error = PostgrestException(
        message: 'column community_posts.visibility does not exist',
        code: '42703');
    expect(communityErrorMessage(error), contains('visibility migration'));
    expect(communityErrorMessage(error), isNot(contains('internet')));
  });
  test('Permission, schema, and connection errors have separate guidance', () {
    expect(
        communityErrorMessage(
            const PostgrestException(message: 'denied', code: '42501')),
        contains('access was denied'));
    expect(
        communityErrorMessage(
            const PostgrestException(message: 'missing', code: 'PGRST205')),
        contains('setup is incomplete'));
    expect(communityErrorMessage(const SocketException('unreachable')),
        contains('internet'));
    expect(communityErrorMessage(TimeoutException('timeout')),
        contains('too long'));
  });
}
