import 'package:flutter_test/flutter_test.dart';
import 'package:pagelit/services/recent_files.dart';

void main() {
  test('RecentFile JSON roundtrip', () {
    final file = RecentFile(
      path: '/storage/emulated/0/Download/example.pdf',
      name: 'example.pdf',
      openedAt: DateTime(2026, 10, 15, 12, 30),
    );
    final restored = RecentFile.fromJson(file.toJson());
    expect(restored.path, file.path);
    expect(restored.name, file.name);
    expect(restored.openedAt, file.openedAt);
  });
}
