// One-off: dart run tool/figma_inspect.dart 150:1125 --file=kwVuEbSWPdrTEFsrIvZVB3
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _api = 'https://api.figma.com/v1';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/figma_inspect.dart <nodeId> [--file=<key>]');
    exitCode = 64;
    return;
  }
  final nodeId = args.first.replaceAll('-', ':');
  var fileKey = 'kwVuEbSWPdrTEFsrIvZVB3';
  for (final a in args.skip(1)) {
    if (a.startsWith('--file=')) fileKey = a.substring(7);
  }
  final token = _readToken();
  if (token.isEmpty) {
    stderr.writeln('Set FIGMA_TOKEN in .env');
    exitCode = 1;
    return;
  }
  final url = Uri.parse(
    '$_api/files/$fileKey/nodes?ids=${Uri.encodeQueryComponent(nodeId)}&depth=8',
  );
  final res = await http.get(url, headers: {'X-Figma-Token': token});
  if (res.statusCode != 200) {
    stderr.writeln('${res.statusCode}: ${res.body}');
    exitCode = 1;
    return;
  }
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final doc = (data['nodes'] as Map)[nodeId]['document'] as Map<String, dynamic>;
  _walk(doc, 0);
}

String _readToken() {
  for (final path in ['.env', '../../.env']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    for (final line in f.readAsLinesSync()) {
      if (line.trim().startsWith('FIGMA_TOKEN=')) {
        return line.substring('FIGMA_TOKEN='.length).trim();
      }
    }
  }
  return Platform.environment['FIGMA_TOKEN'] ?? '';
}

void _walk(Map<String, dynamic> node, int depth) {
  final pad = '  ' * depth;
  final id = node['id'];
  final name = node['name'];
  final type = node['type'];
  final box = node['absoluteBoundingBox'] as Map<String, dynamic>?;
  final w = box != null ? (box['width'] as num?)?.round() : null;
  final h = box != null ? (box['height'] as num?)?.round() : null;
  final style = node['style'] as Map<String, dynamic>?;
  var styleStr = '';
  if (style != null) {
    styleStr =
        ' font=${style['fontFamily']} w=${style['fontWeight']} sz=${style['fontSize']}';
  }
  var fillStr = '';
  final fills = node['fills'] as List<dynamic>?;
  if (fills != null && fills.isNotEmpty) {
    final f = fills.first as Map<String, dynamic>?;
    final c = f?['color'] as Map<String, dynamic>?;
    if (c != null) {
      fillStr =
          ' #${((c['r'] as num) * 255).round().toRadixString(16).padLeft(2, '0')}'
          '${((c['g'] as num) * 255).round().toRadixString(16).padLeft(2, '0')}'
          '${((c['b'] as num) * 255).round().toRadixString(16).padLeft(2, '0')}';
    }
  }
  var extra = '';
  if (node['cornerRadius'] != null) extra += ' r=${node['cornerRadius']}';
  if (node['itemSpacing'] != null) extra += ' gap=${node['itemSpacing']}';
  final pl = node['paddingLeft'];
  if (pl != null) {
    extra +=
        ' pad=${node['paddingLeft']}/${node['paddingRight']}/${node['paddingTop']}/${node['paddingBottom']}';
  }
  stdout.writeln('$pad$id $name ($type) ${w ?? '?'}x${h ?? '?'}$styleStr$fillStr$extra');
  final children = node['children'] as List<dynamic>?;
  if (children != null) {
    for (final c in children) {
      _walk(c as Map<String, dynamic>, depth + 1);
    }
  }
}
