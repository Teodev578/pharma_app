import 'package:flutter/material.dart';

class MapClusterWidget extends StatelessWidget {
  final int count;

  const MapClusterWidget({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
