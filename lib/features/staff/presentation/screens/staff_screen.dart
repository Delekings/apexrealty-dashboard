// lib/features/staff/presentation/screens/staff_screen.dart
import "package:flutter/material.dart";

import "../../../../core/theme/app_theme.dart";

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Staff Performance",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            "Coming next — this page is scaffolded but not yet built.",
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
