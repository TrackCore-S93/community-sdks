// Renders lib/src/generated/*.dart from contract/openapi.json, the API
// contract copied from the community repository. The models, the error codes
// and the list of operations are derived, never retyped.
//
//   dart run tool/generate.dart           write the files
//   dart run tool/generate.dart --check   fail if they would change (CI)
import 'dart:convert';
import 'dart:io';

const _banner =
    '// GENERATED from contract/openapi.json by tool/generate.dart. Do not edit.\n';

late final Map<String, Object?> _schemas;

Map<String, Object?> _map(Object? v) => (v as Map).cast<String, Object?>();

String _camel(String name) {
  final parts =
      name.split(RegExp(r'[_.\-]')).where((p) => p.isNotEmpty).toList();
  final head = parts.first;
  return head +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String _doc(Object? text, String indent) {
  if (text == null) return '';
  final clean =
      text.toString().replaceAll(RegExp(r'\s*\n\s*'), ' ').replaceAll('`', '`');
  return '$indent/// $clean\n';
}

/// Schema names that would clash with a class every Flutter app imports.
const _renamed = {
  'Image': 'CommunityImage',
  'Notification': 'CommunityNotification',
};

String _dartName(String schema) => _renamed[schema] ?? schema;

String _refName(String ref) => ref.substring(ref.lastIndexOf('/') + 1);

/// A property's Dart type and how to read it from JSON.
class _Field {
  _Field(this.type, this.read);
  final String type;
  final String Function(String source) read;
}

_Field _fieldFor(Map<String, Object?> p, {required bool nullable}) {
  String? ref = p[r'$ref'] as String?;
  if (ref == null && p['allOf'] is List && (p['allOf'] as List).length == 1) {
    ref = _map((p['allOf'] as List).first)[r'$ref'] as String?;
  }
  if (ref == null && p['anyOf'] is List) {
    for (final option in p['anyOf'] as List) {
      final r = _map(option)[r'$ref'] as String?;
      if (r != null) ref = r;
      if (_map(option)['type'] == 'null') nullable = true;
    }
  }
  final q = nullable ? '?' : '';
  String orNull(String source, String expr) =>
      nullable ? '$source == null ? null : $expr' : expr;

  if (ref != null) {
    final schema = _refName(ref);
    final name = _dartName(schema);
    final target = _map(_schemas[schema]);
    if (target['enum'] != null) {
      return _Field(
          '$name$q', (s) => orNull(s, '$name.fromWire($s as String?)'));
    }
    return _Field(
        '$name$q',
        (s) =>
            orNull(s, '$name.fromJson(($s as Map).cast<String, Object?>())'));
  }
  final rawType = p['type'];
  final types =
      rawType is List ? rawType.cast<String>() : <String>[rawType as String];
  if (types.contains('null')) {
    nullable = true;
    return _fieldFor({...p, 'type': types.firstWhere((t) => t != 'null')},
        nullable: true);
  }
  switch (types.single) {
    case 'string':
      if (p['format'] == 'date-time') {
        return _Field(
            'DateTime$q', (s) => orNull(s, 'DateTime.parse($s as String)'));
      }
      return _Field('String$q', (s) => '$s as String$q');
    case 'integer':
    case 'number':
      return _Field('int$q',
          (s) => nullable ? '($s as num?)?.toInt()' : '($s as num).toInt()');
    case 'boolean':
      return _Field('bool$q', (s) => '$s as bool$q');
    case 'array':
      final item = _fieldFor(_map(p['items']), nullable: false);
      return _Field(
        'List<${item.type}>$q',
        (s) => orNull(s,
            '($s as List).map((e) => ${item.read('e')}).toList(growable: false)'),
      );
    case 'object':
      return _Field('Map<String, String>$q',
          (s) => orNull(s, '($s as Map).cast<String, String>()'));
  }
  throw StateError('unsupported schema: $p');
}

String _enumMember(String enumName, String value) {
  if (RegExp(r'^[0-9]').hasMatch(value)) {
    return enumName == 'ImageSize' ? 'size$value' : 'v$value';
  }
  return _camel(value);
}

String _models() {
  final out = StringBuffer(_banner)
    ..writeln('// ignore_for_file: unnecessary_lambdas')
    ..writeln();
  for (final entry in _schemas.entries) {
    final name = _dartName(entry.key);
    final s = _map(entry.value);
    if (name.endsWith('Request') ||
        name == 'ErrorEnvelope' ||
        name == 'ErrorBody' ||
        name == 'ErrorCode') {
      continue;
    }
    if (s['enum'] != null) {
      final values = (s['enum'] as List).cast<String>();
      out.write(_doc(s['description'], ''));
      out.writeln('enum $name {');
      for (final v in values) {
        out.writeln("  ${_enumMember(name, v)}('$v'),");
      }
      out
        ..writeln()
        ..writeln(
            '  /// A value this version of the SDK does not know. The API may add values.')
        ..writeln("  unknown('');")
        ..writeln()
        ..writeln('  const $name(this.wire);')
        ..writeln()
        ..writeln('  /// The value as the API sends and accepts it.')
        ..writeln('  final String wire;')
        ..writeln()
        ..writeln('  /// The member for a value from the API, or [unknown].')
        ..writeln('  static $name fromWire(String? value) =>')
        ..writeln(
            '      values.firstWhere((e) => e.wire == value, orElse: () => $name.unknown);')
        ..writeln('}')
        ..writeln();
      continue;
    }
    final props = _map(s['properties']);
    final required =
        ((s['required'] as List?) ?? const []).cast<String>().toSet();
    final fields = <(String, String, _Field, Object?)>[];
    for (final p in props.entries) {
      final field =
          _fieldFor(_map(p.value), nullable: !required.contains(p.key));
      fields.add((p.key, _camel(p.key), field, _map(p.value)['description']));
    }
    out.write(_doc(s['description'], ''));
    out.writeln('final class $name {');
    out.writeln('  /// Builds a [$name]. Normally it comes from the API.');
    out.writeln('  const $name({');
    for (final (_, dart, field, _) in fields) {
      out.writeln(
          '    ${field.type.endsWith('?') ? '' : 'required '}this.$dart,');
    }
    out.writeln('  });');
    out.writeln();
    out.writeln('  /// Reads a [$name] from the API\'s JSON.');
    out.writeln(
        '  factory $name.fromJson(Map<String, Object?> json) => $name(');
    for (final (wire, dart, field, _) in fields) {
      out.writeln("        $dart: ${field.read("json['$wire']")},");
    }
    out.writeln('      );');
    for (final (_, dart, field, doc) in fields) {
      out.writeln();
      out.write(_doc(doc, '  '));
      out.writeln('  final ${field.type} $dart;');
    }
    out.writeln('}');
    out.writeln();
  }
  return out.toString();
}

String _errors(List<Object?> catalogue) {
  final out = StringBuffer(_banner)
    ..writeln()
    ..writeln('/// The closed list of error codes the API answers with.')
    ..writeln('enum CommunityErrorCode {');
  for (final raw in catalogue) {
    final c = _map(raw);
    out.writeln("  /// HTTP ${c['status']}. ${c['message']}");
    out.writeln(
        "  ${_camel(c['code'] as String)}('${c['code']}', ${c['status']}, ${c['retryable']}),");
    out.writeln();
  }
  out
    ..writeln(
        '  /// A code this version of the SDK does not know. Read `rawCode` on the exception.')
    ..writeln("  unknown('', 0, false);")
    ..writeln()
    ..writeln(
        '  const CommunityErrorCode(this.wire, this.httpStatus, this.retryable);')
    ..writeln()
    ..writeln('  /// The code as the API sends it.')
    ..writeln('  final String wire;')
    ..writeln()
    ..writeln('  /// The HTTP status the code is sent with.')
    ..writeln('  final int httpStatus;')
    ..writeln()
    ..writeln('  /// Whether trying the same request again later can succeed.')
    ..writeln('  final bool retryable;')
    ..writeln()
    ..writeln('  /// The member for a code from the API, or [unknown].')
    ..writeln('  static CommunityErrorCode fromWire(String? value) =>')
    ..writeln(
        '      values.firstWhere((e) => e.wire == value, orElse: () => CommunityErrorCode.unknown);')
    ..writeln('}');
  return out.toString();
}

String _operations(Map<String, Object?> doc) {
  final out = StringBuffer(_banner)
    ..writeln()
    ..writeln('/// One route of the API, as the contract describes it.')
    ..writeln(
        'typedef OperationSpec = ({String sdk, String method, String path, String auth});')
    ..writeln()
    ..writeln('/// Every route of the API.')
    ..writeln('const List<OperationSpec> operations = [');
  for (final path in _map(doc['paths']).entries) {
    for (final method in const ['get', 'post', 'put', 'patch', 'delete']) {
      final op = _map(path.value)[method];
      if (op == null) continue;
      final o = _map(op);
      out.writeln(
          "  (sdk: '${o['x-community-sdk']}', method: '${method.toUpperCase()}', path: '${path.key}', auth: '${o['x-community-auth']}'),");
    }
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln(
        '/// The version of the API contract this SDK was generated from.')
    ..writeln(
        "const String contractVersion = '${_map(doc['info'])['version']}';");
  return out.toString();
}

void main(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final doc =
      _map(jsonDecode(File('$root/contract/openapi.json').readAsStringSync()));
  _schemas = _map(_map(doc['components'])['schemas']);
  final files = <String, String>{
    'models.dart': _models(),
    'error_code.dart':
        _errors(doc['x-community-error-catalogue'] as List<Object?>),
    'operations.dart': _operations(doc),
  };
  // Written to a scratch folder inside the package and formatted there, so
  // what is compared (or copied into place) is exactly what `dart format`
  // leaves for this package's own language version.
  final check = args.contains('--check');
  final scratch = Directory('$root/.dart_tool/community_generate')
    ..createSync(recursive: true);
  for (final entry in files.entries) {
    File('${scratch.path}/${entry.key}').writeAsStringSync(entry.value);
  }
  final formatted =
      Process.runSync(Platform.resolvedExecutable, ['format', scratch.path]);
  if (formatted.exitCode != 0) {
    stderr.writeln(formatted.stderr);
    exit(1);
  }
  var stale = false;
  for (final name in files.keys) {
    final text = File('${scratch.path}/$name').readAsStringSync();
    final file = File('$root/lib/src/generated/$name');
    if (check) {
      if (!file.existsSync() || file.readAsStringSync() != text) {
        stderr.writeln(
            'lib/src/generated/$name is out of date; run: dart run tool/generate.dart');
        stale = true;
      }
    } else {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }
  }
  scratch.deleteSync(recursive: true);
  if (stale) exit(1);
  if (!check) stdout.writeln('generated ${files.length} files');
}
