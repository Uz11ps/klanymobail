// Скачивание SVG и растровых ассетов из Figma по официальному API.
//
// 1) Figma → Settings → Security → Generate new token (Personal access token)
// 2) `.env`: FIGMA_TOKEN=figd_... (корень репо или apps/klany_mobile)
// 3) Конфиг: `tool/figma_export_config.json` (`fileKey` по умолчанию + необязательный
//    `fileKey` у каждой строки `exports`, см. ниже).
// 4) Из каталога apps/klany_mobile:
//    dart run tool/figma_export.dart tree 118:1257 --file=kwVuEbSWPdrTEFsrIvZVB3
//    dart run tool/figma_export.dart suggest 118:1305 --file=kwVuEbSWPdrTEFsrIvZVB3
//    dart run tool/figma_export.dart export
//
// Документация: https://www.figma.com/developers/api#get-images-endpoint

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _api = 'https://api.figma.com/v1';
const _configFile = 'tool/figma_export_config.json';

Directory get _packageRoot => File(Platform.script.toFilePath()).parent.parent;

Directory get _repoRoot => _packageRoot.parent.parent;

class _ExportJob {
  _ExportJob({
    required this.fileKey,
    required this.nodeId,
    required this.path,
    required this.format,
    required this.scale,
  });

  final String fileKey;
  final String nodeId;
  final String path;
  final String format;
  /// Для raster (png/jpeg/webp), 1..4 где поддерживается API.
  final double scale;

  String batchKey() => '$fileKey\x1f$format\x1f$scale';
}

/// Возвращает map args без флагов и опционально fileKey после `--file=`.
(Map<String, String> flags, List<String> pos) _parseFlags(List<String> args) {
  final pos = <String>[];
  final flags = <String, String>{};
  for (final a in args) {
    if (a.startsWith('--file=')) {
      flags['file'] = a.substring('--file='.length).trim();
    } else {
      pos.add(a);
    }
  }
  return (flags, pos);
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Использование:\n'
      '  dart run tool/figma_export.dart tree <nodeId> [--file=<fileKey>]  — дерево нод\n'
      '  dart run tool/figma_export.dart suggest <nodeId> [--file=<fileKey>]\n'
      '  dart run tool/figma_export.dart export                             — экспорт из $_configFile\n'
      '\n'
      'В $_configFile у каждой записи экспорта можно указать свой "fileKey" (иначе общий ключ файла).\n'
      'Опционально: "format": "png"|"jpg"|"webp" (по умолчанию svg), для растра — "scale": 2.\n',
    );
    exitCode = 64;
    return;
  }

  final token = _readToken();
  if (token.isEmpty) {
    stderr.writeln(
      'Нет FIGMA_TOKEN. Добавь в .env в корне репозитория или в apps/klany_mobile:\n'
      '  FIGMA_TOKEN=figd_...',
    );
    exitCode = 1;
    return;
  }

  switch (args.first) {
    case 'tree':
      final (flags, pos) = _parseFlags(args.sublist(1));
      if (pos.isEmpty) {
        stderr.writeln('Укажи nodeId, например: dart run tool/figma_export.dart tree 118:1257 --file=kwVuEbSWPdrTEFsrIvZVB3');
        exitCode = 64;
        return;
      }
      await _tree(token, pos.first, flags['file']);
    case 'suggest':
      final (flags, pos) = _parseFlags(args.sublist(1));
      if (pos.isEmpty) {
        stderr.writeln('Укажи nodeId фрейма.');
        exitCode = 64;
        return;
      }
      await _suggest(token, pos.first, flags['file']);
    case 'export':
      await _export(token);
    default:
      stderr.writeln('Неизвестная команда: ${args.first}');
      exitCode = 64;
  }
}

String _readToken() {
  final e = Platform.environment['FIGMA_TOKEN']?.trim();
  if (e != null && e.isNotEmpty) return e;

  final candidates = <File>[
    File(_joinPath(_packageRoot.path, '.env')),
    File(_joinPath(_repoRoot.path, '.env')),
    File('.env'),
  ];
  for (final envFile in candidates) {
    if (!envFile.existsSync()) continue;
    for (final line in envFile.readAsLinesSync()) {
      final t = line.trim();
      if (t.startsWith('FIGMA_TOKEN=')) {
        return t.substring('FIGMA_TOKEN='.length).trim();
      }
    }
  }
  return '';
}

Future<void> _tree(String token, String nodeId, String? overrideFileKey) async {
  final cfg = _loadConfig();
  final normalized = nodeId.replaceAll('-', ':');
  final fileKey =
      overrideFileKey?.trim().isEmpty == false
          ? overrideFileKey!.trim()
          : cfg['fileKey'] as String? ?? 'z72tmzXGfrKzFPQMqrL1ZB';
  final url = Uri.parse(
    '$_api/files/$fileKey/nodes?ids=${Uri.encodeQueryComponent(normalized)}&depth=4',
  );
  final res = await http.get(url, headers: {'X-Figma-Token': token});
  if (res.statusCode != 200) {
    stderr.writeln('Figma API ${res.statusCode}: ${res.body}');
    exitCode = 1;
    return;
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final nodes = data['nodes'] as Map<String, dynamic>?;
  if (nodes == null || nodes.isEmpty) {
    stderr.writeln('Нода не найдена. Проверь id и fileKey (--file=...). Формат id: 12:34.');
    exitCode = 1;
    return;
  }
  for (final entry in nodes.entries) {
    final doc = (entry.value as Map)['document'] as Map<String, dynamic>?;
    if (doc != null) {
      stdout.writeln('fileKey=$fileKey\n');
      _printNode(doc, 0);
    }
  }
}

Future<void> _suggest(String token, String nodeId, String? overrideFileKey) async {
  final cfg = _loadConfig();
  final normalized = nodeId.replaceAll('-', ':');
  final fileKey =
      overrideFileKey?.trim().isEmpty == false
          ? overrideFileKey!.trim()
          : cfg['fileKey'] as String? ?? 'z72tmzXGfrKzFPQMqrL1ZB';
  final url = Uri.parse(
    '$_api/files/$fileKey/nodes?ids=${Uri.encodeQueryComponent(normalized)}&depth=8',
  );
  final res = await http.get(url, headers: {'X-Figma-Token': token});
  if (res.statusCode != 200) {
    stderr.writeln('Figma API ${res.statusCode}: ${res.body}');
    exitCode = 1;
    return;
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final nodes = data['nodes'] as Map<String, dynamic>?;
  if (nodes == null || nodes.isEmpty) {
    stderr.writeln('Нода не найдена.');
    exitCode = 1;
    return;
  }
  final hint = RegExp(
    r'bag|shop|магаз|home|house|дом|tune|slider|refresh|refresh|dots|меню|checkbox|exchange|birz|зац|coin|divider|line|стрел|svg|fi-br',
    caseSensitive: false,
  );
  final types = {'VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'ELLIPSE', 'LINE'};
  stdout.writeln('fileKey=$fileKey\n');
  for (final entry in nodes.entries) {
    final doc = (entry.value as Map)['document'] as Map<String, dynamic>?;
    if (doc != null) {
      _collectSuggest(doc, hint, types);
    }
  }
}

void _collectSuggest(
  Map<String, dynamic> node,
  RegExp hint,
  Set<String> types,
) {
  final id = node['id']?.toString() ?? '';
  final name = node['name']?.toString() ?? '';
  final type = node['type']?.toString() ?? '';
  if (types.contains(type) || hint.hasMatch(name)) {
    stdout.writeln('$id\t$name\t($type)');
  }
  final children = node['children'] as List<dynamic>?;
  if (children != null) {
    for (final c in children) {
      _collectSuggest(c as Map<String, dynamic>, hint, types);
    }
  }
}

void _printNode(Map<String, dynamic> node, int depth) {
  final pad = '  ' * depth;
  final id = node['id'];
  final name = node['name'];
  final type = node['type'];
  stdout.writeln('$pad$id  $name  ($type)');
  final children = node['children'] as List<dynamic>?;
  if (children != null) {
    for (final c in children) {
      _printNode(c as Map<String, dynamic>, depth + 1);
    }
  }
}

Map<String, dynamic> _loadConfig() {
  final f = File(_joinPath(_packageRoot.path, _configFile));
  if (!f.existsSync()) {
    return {'fileKey': 'z72tmzXGfrKzFPQMqrL1ZB'};
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

Future<void> _export(String token) async {
  final cfg = _loadConfig();
  final defaultFileKey = cfg['fileKey'] as String? ?? 'z72tmzXGfrKzFPQMqrL1ZB';
  final exports = cfg['exports'];
  if (exports is! List) {
    stderr.writeln('В $_configFile нет массива "exports".');
    exitCode = 1;
    return;
  }

  final jobs = <_ExportJob>[];
  for (final raw in exports) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    if (m.containsKey('comment')) continue;
    final id = (m['nodeId'] ?? m['node_id'])?.toString().trim().replaceAll('-', ':') ?? '';
    final path = (m['path'] ?? '').toString().trim();
    if (id.isEmpty || path.isEmpty) continue;
    final fk = (m['fileKey'] ?? m['file_key'] ?? '').toString().trim();
    final fileKey = fk.isEmpty ? defaultFileKey : fk;
    final format = ((m['format'] ?? 'svg') as Object).toString().toLowerCase().trim();
    final scaleRaw = m['scale'];
    final scale = scaleRaw is num ? scaleRaw.toDouble().clamp(0.01, 4).toDouble() : 1.0;
    jobs.add(
      _ExportJob(
        fileKey: fileKey,
        nodeId: id,
        path: path,
        format: format,
        scale: scale,
      ),
    );
  }
  if (jobs.isEmpty) {
    stderr.writeln('Нет валидных записей export. Заполни nodeId в $_configFile');
    exitCode = 1;
    return;
  }

  final batches = <String, List<_ExportJob>>{};
  for (final j in jobs) {
    batches.putIfAbsent(j.batchKey(), () => []).add(j);
  }

  for (final list in batches.values) {
    await _exportBatch(token, list);
  }
}

Future<void> _exportBatch(String token, List<_ExportJob> jobs) async {
  if (jobs.isEmpty) return;
  final fk = jobs.first.fileKey;
  final format = jobs.first.format;
  final scale = jobs.first.scale;

  final ids = jobs.map((e) => e.nodeId).join(',');
  final qp = <String, String>{
    'ids': ids,
    'format': format,
  };
  if (format == 'svg') {
    qp['svg_outline_text'] = 'true';
    qp['svg_simplify_stroke'] = 'true';
  } else {
    final s =
        scale == scale.roundToDouble()
            ? scale.round().clamp(1, 4).toInt().toString()
            : scale.toString();
    qp['scale'] = s;
  }

  final imgUrl = Uri.parse('$_api/images/$fk').replace(queryParameters: qp);
  final imgRes = await http.get(imgUrl, headers: {'X-Figma-Token': token});
  if (imgRes.statusCode != 200) {
    stderr.writeln('images API ($fk ${format}s${format == 'svg' ? '' : '@${qp['scale']}'}) ${imgRes.statusCode}: ${imgRes.body}');
    exitCode = 1;
    return;
  }
  final imgJson = jsonDecode(imgRes.body) as Map<String, dynamic>;
  final images = imgJson['images'] as Map<String, dynamic>?;
  if (images == null) {
    stderr.writeln('Пустой ответ images: ${imgRes.body}');
    exitCode = 1;
    return;
  }

  for (final job in jobs) {
    final url = images[job.nodeId]?.toString();
    if (url == null || url.isEmpty) {
      stderr.writeln('Нет URL для ${job.nodeId} (file=$fk)');
      continue;
    }
    final svgRes = await http.get(Uri.parse(url));
    if (svgRes.statusCode != 200) {
      stderr.writeln('Скачивание ${job.path}: ${svgRes.statusCode}');
      continue;
    }
    final out = File(_resolveOutputPath(job.path));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(svgRes.bodyBytes);
    stdout.writeln('OK ${job.path} <- ${job.nodeId} ($fk ${job.format}${job.format != 'svg' ? ' @${job.scale}' : ''})');
  }
}

/// Путь записи всегда относительно [apps/klany_mobile].
String _resolveOutputPath(String publishPath) {
  final cwd = Directory.current.path;
  if (publishPath.startsWith('assets${Platform.pathSeparator}') ||
      publishPath.startsWith('assets/')) {
    return _joinPath(_packageRoot.path, publishPath.replaceAll('/', Platform.pathSeparator));
  }
  if (publishPath.startsWith('/') ||
      (publishPath.length >= 2 &&
          publishPath[1] == ':')) {
    return publishPath;
  }
  return _joinPath(cwd, publishPath);
}

String _joinPath(String a, String b) {
  if (b.startsWith('/') || (b.length >= 2 && b[1] == ':')) return b;
  final sep = Platform.pathSeparator;
  if (a.endsWith(sep)) return '$a$b';
  return '$a$sep$b';
}
