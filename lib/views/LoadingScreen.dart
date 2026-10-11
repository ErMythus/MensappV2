import 'package:flutter/material.dart';
import 'package:mensapp_v2/utils/cardutils.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  Future<void> loadData(BuildContext context) async {
    final profiles = await ProfileManager.getAllProfiles();
    
    if (context.mounted) {
      if (profiles.isEmpty) {
        Navigator.pushReplacementNamed(context, "/add_code");
      } else {
        final currentProfile = await ProfileManager.getCurrentProfile();
        if (currentProfile != null) {
          Navigator.pushReplacementNamed(context, "/home");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    loadData(context);
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
