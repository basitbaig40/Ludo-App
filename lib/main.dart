import 'package:flutter/material.dart';

void main() {
  runApp(const LudoApp());
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ludo Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LudoHomeScreen(),
    );
  }
}

class LudoHomeScreen extends StatelessWidget {
  const LudoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Game Online'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.casino, size: 100, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Ludo Game!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Play Online'),
            ),
          ],
        ),
      ),
    );
  }
}
