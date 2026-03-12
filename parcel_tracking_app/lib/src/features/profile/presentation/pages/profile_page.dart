import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (user != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(user.email ?? 'Signed-in user'),
                subtitle: const Text('Tap below to sign out'),
              ),
            ] else
              const Text('No user is currently signed in.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: user == null
                    ? null
                    : () async {
                        await auth.signOut();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signed out successfully.')),
                          );
                        }
                      },
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

