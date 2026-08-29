import 'package:flutter/material.dart';

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
