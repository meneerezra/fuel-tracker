import 'package:flutter/material.dart';

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({super.key});

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('Auth token'),
              subtitle: const Text("Add an authentication token"),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
