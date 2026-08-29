import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hobbs_ui/models/session.dart';
import 'package:hobbs_ui/session_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when nothing has been saved', () async {
    expect(await SessionStore.load(), isNull);
  });

  test('save then load round-trips the session', () async {
    const session = Session(
      sessionId: 'session-1',
      pilotId: 'pilot-1',
      name: 'Wills',
      admin: false,
    );

    await SessionStore.save(session);
    final loaded = await SessionStore.load();

    expect(loaded?.sessionId, session.sessionId);
    expect(loaded?.pilotId, session.pilotId);
    expect(loaded?.name, session.name);
    expect(loaded?.admin, session.admin);
  });

  test('clear removes the saved session', () async {
    const session =
        Session(sessionId: 's', pilotId: 'p', name: 'Wills', admin: true);
    await SessionStore.save(session);

    await SessionStore.clear();

    expect(await SessionStore.load(), isNull);
  });
}
