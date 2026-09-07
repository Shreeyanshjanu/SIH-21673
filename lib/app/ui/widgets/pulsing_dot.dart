import 'package:flutter/material.dart';

/// Small circular dot with a pulsing ping ring, used for status indicators.
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    required this.color,
    this.size = 8,
    this.ping = true,
  });

  final Color color;
  final double size;
  final bool ping;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.ping) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
      ),
    );

    if (!widget.ping) {
      return dot;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Transform.scale(
                scale: 1 + (1.2 * _controller.value),
                child: Opacity(
                  opacity: (1 - _controller.value) * 0.7,
                  child: dot,
                ),
              ),
              dot,
            ],
          ),
        );
      },
    );
  }
}