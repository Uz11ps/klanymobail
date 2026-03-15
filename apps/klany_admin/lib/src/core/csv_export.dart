import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart';

String toCsv(List<Map<String, dynamic>> rows, List<String> columns) {
  String esc(Object? v) {
    final s = (v ?? '').toString();
    final needs = s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
    if (!needs) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  final b = StringBuffer();
  b.writeln(columns.map(esc).join(','));
  for (final row in rows) {
    b.writeln(columns.map((c) => esc(row[c])).join(','));
  }
  return b.toString();
}

void downloadCsv(String filename, List<Map<String, dynamic>> rows, List<String> columns) {
  downloadTextFile(filename, toCsv(rows, columns));
}

