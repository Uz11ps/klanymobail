import 'package:flutter/material.dart';

import '../features/home/child_soft_ui.dart';

/// Полноэкранная загрузка до первого показа контента (как splash, но внутри shell).
class KlanyPageLoading extends StatelessWidget {
  const KlanyPageLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B78E0),
                      kChildBrandBlue,
                      kChildBrandBlueDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D2E63D8),
                      blurRadius: 20,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_moon,
                  size: 46,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              if (message != null) ...[
                Text(
                  message!,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kChildInkMuted,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  color: kChildBrandBlue,
                  backgroundColor: Color(0xFFD7E1F2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Плавное появление контента после bootstrap.
class KlanyPageReveal extends StatefulWidget {
  const KlanyPageReveal({super.key, required this.child});

  final Widget child;

  @override
  State<KlanyPageReveal> createState() => _KlanyPageRevealState();
}

class _KlanyPageRevealState extends State<KlanyPageReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.018),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// IndexedStack: монтирует вкладку только после первого открытия.
class KlanyLazyIndexedStack extends StatelessWidget {
  const KlanyLazyIndexedStack({
    super.key,
    required this.index,
    required this.visited,
    required this.children,
  });

  final int index;
  final Set<int> visited;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: List.generate(children.length, (i) {
        if (!visited.contains(i)) return const SizedBox.shrink();
        return children[i];
      }),
    );
  }
}
