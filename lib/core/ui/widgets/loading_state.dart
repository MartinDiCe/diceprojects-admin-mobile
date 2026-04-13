import 'package:app_diceprojects_admin/core/ui/widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';

class LoadingState extends StatelessWidget {
  final String? message;
  /// When true renders skeleton list; false shows centered spinner.
  final bool asSkeleton;

  const LoadingState({super.key, this.message, this.asSkeleton = true});

  @override
  Widget build(BuildContext context) {
    if (asSkeleton) return const SkeletonListLoader();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF387EBC),
            strokeWidth: 2.5,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }
}
