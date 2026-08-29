import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hobbs_ui/remembered_identifier.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when nothing has been saved', () async {
    expect(await RememberedIdentifier.load(), isNull);
  });

  test('save then load round-trips the identifier', () async {
    await RememberedIdentifier.save('wills@example.com');

    expect(await RememberedIdentifier.load(), 'wills@example.com');
  });

  test('clear removes the saved identifier', () async {
    await RememberedIdentifier.save('wills@example.com');

    await RememberedIdentifier.clear();

    expect(await RememberedIdentifier.load(), isNull);
  });
}
