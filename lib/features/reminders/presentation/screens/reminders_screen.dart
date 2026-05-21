// lib/features/reminders/presentation/screens/reminders_screen.dart
import "package:flutter/material.dart";

import "../../../../core/theme/app_theme.dart";

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Reminders & Alerts",
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
