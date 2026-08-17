import 'dart:io';

import 'package:image/image.dart' as img;

/// Pads branding/locker.png into an adaptive-icon-safe foreground canvas.
/// Does not modify assets/images/branding/locker.png.
///
/// flutter_launcher_icons applies a further ~16% inset in ic_launcher.xml,
/// so we keep logo content near ~90% of this canvas (~60% of the final icon,
/// inside Android's 66% safe zone).
void main() {
  final srcFile = File('assets/images/branding/locker.png');
  if (!srcFile.existsSync()) {
    stderr.writeln('Missing assets/images/branding/locker.png');
    exit(1);
  }
  final src = img.decodeImage(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode locker.png');
    exit(1);
  }

  const size = 1024;
  const contentRatio = 0.90;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final maxSide = (size * contentRatio).round();
  final scale = maxSide / (src.width > src.height ? src.width : src.height);
  final w = (src.width * scale).round().clamp(1, maxSide);
  final h = (src.height * scale).round().clamp(1, maxSide);
  final resized = img.copyResize(
    src,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );
  final left = ((size - w) / 2).round();
  final top = ((size - h) / 2).round();
  img.compositeImage(canvas, resized, dstX: left, dstY: top);

  final out = File('android/branding/locker_adaptive_foreground.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln(
    'Wrote ${out.path} (${size}x$size, content ~${(contentRatio * 100).round()}%)',
  );
}
