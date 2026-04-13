import 'package:flutter/material.dart';

class CreateFab extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const CreateFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      shape: const StadiumBorder(),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
    );
  }
}
