import 'package:material_ui/material_ui.dart';

/// Compact, straight-edged icon tile used for feature and fallback artwork.
class GeometricIconTile extends StatelessWidget {
  const GeometricIconTile({
    required this.size,
    required this.color,
    required this.child,
    this.onTap,
    this.radius = 10,
    super.key,
  });

  final double size;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Center(child: child)
            : InkWell(onTap: onTap, child: Center(child: child)),
      ),
    );
  }
}
