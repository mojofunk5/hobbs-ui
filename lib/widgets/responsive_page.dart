import 'package:flutter/material.dart';

/// Centers [child] and bounds its width everywhere, additionally wrapping it in a [Card] once the
/// viewport is wide enough - without this, content just floats in a sea of blank space on a
/// desktop-width window with no framing, reading as an unstyled phone screen left stranded rather
/// than an intentional layout.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.child, this.maxWidth = 480});

  final Widget child;
  final double maxWidth;

  static const _wideBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final padded = Padding(padding: const EdgeInsets.all(24), child: child);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: isWide ? Card(margin: EdgeInsets.zero, child: padded) : padded,
      ),
    );
  }
}
