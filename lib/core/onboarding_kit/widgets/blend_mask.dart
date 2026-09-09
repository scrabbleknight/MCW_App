import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Composites [child] over what's behind it using [blendMode].
///
/// Use this to drop a black background out of a photo asset without an alpha
/// channel: wrap the [Image] in `BlendMask(blendMode: BlendMode.screen, ...)`
/// on top of a coloured backdrop and the black pixels contribute nothing to
/// the composite, while lit pixels punch through.
class BlendMask extends SingleChildRenderObjectWidget {
  const BlendMask({
    super.key,
    required this.blendMode,
    super.child,
  });

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlendMask(blendMode);

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenderBlendMask).blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);

  BlendMode _blendMode;
  BlendMode get blendMode => _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    super.paint(context, offset);
    context.canvas.restore();
  }
}
