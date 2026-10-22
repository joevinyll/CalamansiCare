import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calamansi_care/data/community_notifications.dart';
import 'support/fake_community_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Unread count, new-event sound, read state and silent initial load',
      () async {
    final repo = FakeCommunityRepository();
    addTearDown(repo.close);
    final first = <String, dynamic>{'id': 'a', 'read_at': null};
    repo.notificationRows = [first];
    var sounds = 0;
    final notifications = CommunityNotifications(repo, ding: () async {
      sounds++;
    });
    addTearDown(notifications.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(notifications.unread, 1);
    expect(sounds, 0);
    final second = <String, dynamic>{'id': 'b', 'read_at': null};
    repo.notificationChanges.add([first, second]);
    await Future<void>.delayed(Duration.zero);
    expect(notifications.unread, 2);
    expect(sounds, 1);
    repo.notificationChanges.add([first, second]);
    await Future<void>.delayed(Duration.zero);
    expect(sounds, 1);
    await notifications.markRead('b');
    expect(notifications.unread, 1);
    notifications.didChangeAppLifecycleState(AppLifecycleState.paused);
    repo.notificationChanges.add([
      first,
      {...second, 'read_at': 'read'},
      {'id': 'c', 'read_at': null}
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(sounds, 1);
  });
}
