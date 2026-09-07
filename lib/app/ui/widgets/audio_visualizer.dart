import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Animated acoustic spectrogram bar visualizer with dB indicator.
class AudioVisualizer extends StatefulWidget {
  const AudioVisualizer({super.key, required this.active});

  final bool active;

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> {
  static const int _barCount = 15;
  final Random _random = Random();
  late final List<double> _heights;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _heights = List<double>.generate(
      _barCount,
      (_) => _random.nextDouble(),
      growable: false,
    );
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _startTimer();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: widget.active ? 90 : 400),
      (_) {
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            _heights[i] = widget.active
                ? 0.2 + (_random.nextDouble() * 0.8)
                : 0.08 + (_random.nextDouble() * 0.35);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color barColor = widget.active
        ? AppColors.primaryContainer
        : AppColors.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'ACOUSTIC SPECTROGRAM',
                style: AppTypography.labelCaps.copyWith(
                  color: AppColors.outline,
                  letterSpacing: 0.12,
                ),
              ),
              const Spacer(),
              Text(
                widget.active ? '-14 dB (PEAK VOX)' : '-42 dB (SILENCE)',
                style: AppTypography.telemetrySm.copyWith(
                  color: widget.active
                      ? AppColors.primaryContainer
                      : AppColors.tertiary,
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(_barCount, (int i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 75),
                      height: _heights[i] * 36,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}