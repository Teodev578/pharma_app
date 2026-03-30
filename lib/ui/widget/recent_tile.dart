import 'package:flutter/material.dart';

class RecentTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const RecentTile({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Colors.redAccent,
        child: Icon(Icons.local_pharmacy, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.more_horiz, color: Colors.grey),
    );
  }
}
