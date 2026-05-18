// Скачивание SVG из Figma по официальному API (не «наугад»).
//
// 1) Figma → Settings → Security → Generate new token (Personal access token)
// 2) Скопируй в `.env`: FIGMA_TOKEN=figd_...
//    или в PowerShell: $env:FIGMA_TOKEN="figd_..."
// 3) Скопируй `tool/figma_export_config.example.json` → `tool/figma_export_config.json`
//    и подставь реальные nodeId (из URL node-id=12-34 → в JSON "12:34")
// 4) Из каталога apps/klany_mobile:
//    dart run tool/figma_export.dart tree 0:81
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

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Использование:\n'
      '  dart run tool/figma_export.dart tree <nodeId>    — дерево нод (id как 0:81)\n'
      '  dart run tool/figma_export.dart suggest <nodeId> — кандидаты иконок (VECTOR / по имени)\n'
      '  dart run tool/figma_export.dart export           — SVG по tool/figma_export_config.json\n',
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
      if (args.length < 2) {
        stderr.writeln('Укажи nodeId, например: dart run tool/figma_export.dart tree 0:81');
        exitCode = 64;
        return;
      }
      await _tree(token, args[1]);
    case 'suggest':
      if (args.length < 2) {
        stderr.writeln('Укажи nodeId фрейма, например: dart run tool/figma_export.dart suggest 0:81');
        exitCode = 64;
        return;
      }
      await _suggest(token, args[1]);
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

Future<void> _tree(String token, String nodeId) async {
  final cfg = _loadConfig();
  final normalized = nodeId.replaceAll('-', ':');
  final fileKey = cfg['fileKey'] as String? ?? 'z72tmzXGfrKzFPQMqrL1ZB';
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
    stderr.writeln('Нода не найдена. Проверь id (формат 12:34, не 12-34).');
    exitCode = 1;
    return;
  }
  for (final entry in nodes.entries) {
    final doc = (entry.value as Map)['document'] as Map<String, dynamic>?;
    if (doc != null) {
      _printNode(doc, 0);
    }
  }
}

Future<void> _suggest(String token, String nodeId) async {
  final cfg = _loadConfig();
  final normalized = nodeId.replaceAll('-', ':');
  final fileKey = cfg['fileKey'] as String? ?? 'z72tmzXGfrKzFPQMqrL1ZB';
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
    r'bag|shop|магаз|home|house|дом|tune|slider|фильтр|настрой|settings|nav|tab|icon|ico',
    caseSensitive: false,
  );
  final types = {'VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'ELLIPSE', 'LINE'};
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
  final f = File(_configFile);
  if (!f.existsSync()) {
    return {'fileKey': 'z72tmzXGfrKzFPQMqrL1ZB'};
  }
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}

Future<void> _export(String token) async {
  final cfg = _loadConfig();
  final fileKey = cfg['fileKey'] as String? ?? 'z72tmzXGfrKzFPQMqrL1ZB';
  final exports = cfg['exports'];
  if (exports is! List) {
    stderr.writeln('В $_configFile нет массива "exports".');
    exitCode = 1;
    return;
  }

  final jobs = <({String nodeId, String path})>[];
  for (final raw in exports) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    if (m.containsKey('comment')) continue;
    final id = (m['nodeId'] ?? m['node_id'])?.toString().trim().replaceAll('-', ':') ?? '';
    final path = (m['path'] ?? '').toString().trim();
    if (id.isEmpty || path.isEmpty) continue;
    jobs.add((nodeId: id, path: path));
  }
  if (jobs.isEmpty) {
    stderr.writeln('Нет валидных записей export. Заполни nodeId в $_configFile');
    exitCode = 1;
    return;
  }

  final ids = jobs.map((e) => e.nodeId).join(',');
  final imgUrl = Uri.parse('$_api/images/$fileKey').replace(
    queryParameters: {
      'ids': ids,
      'format': 'svg',
      'svg_outline_text': 'true',
      'svg_simplify_stroke': 'true',
    },
  );
  final imgRes = await http.get(imgUrl, headers: {'X-Figma-Token': token});
  if (imgRes.statusCode != 200) {
    stderr.writeln('images API ${imgRes.statusCode}: ${imgRes.body}');
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

  final root = Directory.current;
  for (final job in jobs) {
    final url = images[job.nodeId]?.toString();
    if (url == null || url.isEmpty) {
      stderr.writeln('Нет URL для ${job.nodeId}');
      continue;
    }
    final svgRes = await http.get(Uri.parse(url));
    if (svgRes.statusCode != 200) {
      stderr.writeln('Скачивание ${job.path}: ${svgRes.statusCode}');
      continue;
    }
    final out = File(_joinPath(root.path, job.path));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(svgRes.bodyBytes);
    stdout.writeln('OK ${job.path} <- ${job.nodeId}');
  }
}

String _joinPath(String a, String b) {
  if (b.startsWith('/') || (b.length >= 2 && b[1] == ':')) return b;
  final sep = Platform.pathSeparator;
  if (a.endsWith(sep)) return '$a$b';
  return '$a$sep$b';
}
