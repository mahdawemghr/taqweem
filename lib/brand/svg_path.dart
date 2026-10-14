import 'dart:ui' as ui;

/// Parses SVG path data (the `d` attribute) into a [ui.Path].
///
/// Supported commands, absolute and relative: `M L H V C S Q T Z`
/// (implicit repeats, e.g. `M0 0 10 10` = move + line, and the compact
/// number forms `1.5.5`, `-1-2`, `1e-3` are handled). Elliptical arcs
/// (`A`) are not used by the generated brand paths and throw a
/// [FormatException], as does any malformed input.
///
/// The returned path uses [fillType] (default even-odd, which is what the
/// traced logo layers need: holes are separate sub-paths).
ui.Path parseSvgPath(
  String data, {
  ui.PathFillType fillType = ui.PathFillType.evenOdd,
}) {
  final path = ui.Path()..fillType = fillType;
  final s = _Scanner(data);
  var cx = 0.0, cy = 0.0; // current point
  var sx = 0.0, sy = 0.0; // sub-path start
  var lcx = 0.0, lcy = 0.0; // last control point (for S / T)
  var last = '';
  var cmd = '';
  while (true) {
    s.skipSeparators();
    if (s.done) break;
    if (s.atCommand) {
      cmd = s.readCommand();
    } else if (cmd.isEmpty) {
      throw FormatException('Path data must start with a command', data, s.pos);
    } else if (cmd == 'M') {
      cmd = 'L'; // implicit repeats of a moveto are linetos
    } else if (cmd == 'm') {
      cmd = 'l';
    } else if (cmd == 'Z' || cmd == 'z') {
      throw FormatException('Unexpected number after Z', data, s.pos);
    }
    final rel = cmd.toLowerCase() == cmd;
    final ox = rel ? cx : 0.0, oy = rel ? cy : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        cx = ox + s.number();
        cy = oy + s.number();
        sx = cx;
        sy = cy;
        path.moveTo(cx, cy);
      case 'L':
        cx = ox + s.number();
        cy = oy + s.number();
        path.lineTo(cx, cy);
      case 'H':
        cx = ox + s.number();
        path.lineTo(cx, cy);
      case 'V':
        cy = (rel ? cy : 0.0) + s.number();
        path.lineTo(cx, cy);
      case 'C':
        final x1 = ox + s.number(), y1 = oy + s.number();
        final x2 = ox + s.number(), y2 = oy + s.number();
        cx = ox + s.number();
        cy = oy + s.number();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
        lcx = x2;
        lcy = y2;
      case 'S':
        final smooth = last == 'C' || last == 'S';
        final x1 = smooth ? 2 * cx - lcx : cx;
        final y1 = smooth ? 2 * cy - lcy : cy;
        final x2 = ox + s.number(), y2 = oy + s.number();
        cx = ox + s.number();
        cy = oy + s.number();
        path.cubicTo(x1, y1, x2, y2, cx, cy);
        lcx = x2;
        lcy = y2;
      case 'Q':
        final x1 = ox + s.number(), y1 = oy + s.number();
        cx = ox + s.number();
        cy = oy + s.number();
        path.quadraticBezierTo(x1, y1, cx, cy);
        lcx = x1;
        lcy = y1;
      case 'T':
        final smooth = last == 'Q' || last == 'T';
        final x1 = smooth ? 2 * cx - lcx : cx;
        final y1 = smooth ? 2 * cy - lcy : cy;
        cx = ox + s.number();
        cy = oy + s.number();
        path.quadraticBezierTo(x1, y1, cx, cy);
        lcx = x1;
        lcy = y1;
      case 'Z':
        path.close();
        cx = sx;
        cy = sy;
      default:
        throw FormatException('Unsupported path command "$cmd"', data, s.pos);
    }
    last = cmd.toUpperCase();
  }
  return path;
}

class _Scanner {
  _Scanner(this.src);

  final String src;
  int pos = 0;

  bool get done => pos >= src.length;

  static bool _isSep(int c) =>
      c == 0x20 || c == 0x2C || c == 0x09 || c == 0x0A || c == 0x0D;

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  void skipSeparators() {
    while (!done && _isSep(src.codeUnitAt(pos))) {
      pos++;
    }
  }

  bool get atCommand {
    final c = src.codeUnitAt(pos);
    final isLetter = (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
    return isLetter && c != 0x65 && c != 0x45; // 'e'/'E' only in numbers
  }

  String readCommand() => src[pos++];

  double number() {
    skipSeparators();
    final start = pos;
    if (!done && (src[pos] == '-' || src[pos] == '+')) pos++;
    var digits = 0;
    var dot = false;
    while (!done) {
      final c = src.codeUnitAt(pos);
      if (_isDigit(c)) {
        digits++;
        pos++;
      } else if (c == 0x2E && !dot) {
        dot = true;
        pos++;
      } else {
        break;
      }
    }
    if (digits == 0) {
      throw FormatException('Expected a number', src, start);
    }
    if (!done && (src[pos] == 'e' || src[pos] == 'E')) {
      final save = pos;
      pos++;
      if (!done && (src[pos] == '-' || src[pos] == '+')) pos++;
      var exp = 0;
      while (!done && _isDigit(src.codeUnitAt(pos))) {
        exp++;
        pos++;
      }
      if (exp == 0) pos = save;
    }
    return double.parse(src.substring(start, pos));
  }
}
