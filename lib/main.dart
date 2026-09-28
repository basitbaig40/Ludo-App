import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const LudoApp());
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ludo Multiplayer',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const LudoBoardScreen(),
    );
  }
}

class LudoBoardScreen extends StatefulWidget {
  const LudoBoardScreen({super.key});

  @override
  State<LudoBoardScreen> createState() => _LudoBoardScreenState();
}

class _LudoBoardScreenState extends State<LudoBoardScreen> {
  int diceValue = 1;
  bool isRolling = false;
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    initSocket();
  }

  void initSocket() {
    // Apne Node.js server URL se replace karein jab server deploy ho jaye
    socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) => print('Connected to Server'));
  }

  void rollDice() {
    if (isRolling) return;
    setState(() => isRolling = true);

    int rolls = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        diceValue = Random().nextInt(6) + 1;
      });
      rolls++;
      if (rolls >= 10) {
        timer.cancel();
        setState(() => isRolling = false);
        socket.emit('diceRolled', {'value': diceValue});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double size = MediaQuery.of(context).size.width - 32;

    return Scaffold(
      appBar: AppBar(title: const Text('Ludo Multiplayer'), centerTitle: true),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Ludo Board UI
          Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: Stack(
                children: [
                  // 4 Corner Quadrants
                  Positioned(top: 0, left: 0, child: _buildHomeBase(Colors.red, size)),
                  Positioned(top: 0, right: 0, child: _buildHomeBase(Colors.green, size)),
                  Positioned(bottom: 0, left: 0, child: _buildHomeBase(Colors.blue, size)),
                  Positioned(bottom: 0, right: 0, child: _buildHomeBase(Colors.yellow, size)),
                  // Center Home Triangle
                  Center(
                    child: Container(
                      width: size * 0.2,
                      height: size * 0.2,
                      color: Colors.amber[700],
                      child: const Icon(Icons.star, color: Colors.white, size: 40),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dice System
          GestureDetector(
            onTap: rollDice,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    isRolling ? 'Rolling...' : 'Tap to Roll',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$diceValue',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBase(Color color, double boardSize) {
    double baseSize = boardSize * 0.4;
    return Container(
      width: baseSize,
      height: baseSize,
      color: color,
      padding: const EdgeInsets.all(16),
      child: Container(
        color: Colors.white,
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(8),
          children: List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
