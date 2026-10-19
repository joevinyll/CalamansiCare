import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Supabase scripts preserve feed fields but redact reporter identity and coordinates',
      () {
    for (final file in [
      'supabase/auth_setup.sql',
      'supabase/report_images_setup.sql',
      'supabase/migrations/20261019000000_security_hardening.sql',
      'supabase/migrations/20261019030000_city_only_community_locations.sql',
    ]) {
      final sql = File(file).readAsStringSync();
      expect(sql, contains("'Anonymous farmer'::text as farmer_name"),
          reason: file);
      if (file.endsWith('20261019000000_security_hardening.sql')) {
        expect(sql, contains("'Barangay area'::text as farmer_location"),
            reason: file);
      } else {
        expect(
          sql,
          contains(
              'public.city_only_report_location(farmer_location) as farmer_location'),
          reason: file,
        );
      }
      expect(sql, contains('null::double precision as latitude'), reason: file);
      expect(sql, contains('null::double precision as longitude'),
          reason: file);
    }
  });

  test('city-only location projection has a safe fallback and no raw address',
      () {
    final migration = File(
            'supabase/migrations/20261019030000_city_only_community_locations.sql')
        .readAsStringSync();
    expect(migration, contains("return 'General area'"));
    expect(migration, contains("return 'Bansalan'"));
    expect(
        migration,
        contains(
            "grant execute on function public.city_only_report_location(text) to anon, authenticated"));
    expect(migration, contains('null::double precision as latitude'));
    expect(migration, contains('null::double precision as longitude'));
  });

  test('image update policies require the authenticated object owner', () {
    final migration =
        File('supabase/migrations/20261019000000_security_hardening.sql')
            .readAsStringSync();
    expect(
        migration,
        contains(
            'using (bucket_id = \'report-images\' and owner_id = (select auth.uid())::text)'));
    expect(
        migration,
        contains(
            'with check (bucket_id = \'report-images\' and owner_id = (select auth.uid())::text'));
    expect(migration, contains("file_size_limit = 5242880"));
    expect(migration, contains("array['image/webp']"));
  });

  test('user-selected email recipients retain report authorization controls',
      () {
    final migration = File(
            'supabase/migrations/20261019020000_allow_user_selected_report_recipients.sql')
        .readAsStringSync();
    expect(migration, contains('user_id = caller and consent = true'));
    expect(migration, contains('report_email_deliveries'));
    expect(migration, contains("interval '1 hour') >= 10"));
    expect(migration, isNot(contains('report_email_offices')));
    expect(migration, isNot(contains('recipient_not_approved')));
  });
}
