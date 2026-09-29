import 'dart:async';
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
      title: 'Ludo Billionaires',
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

  // Track token positions (0 means home base)
  Map<String, List<int>> tokenPositions = {
    'red': [0, 0, 0, 0],
    'green': [0, 0, 0, 0],
    'yellow': [0, 0, 0, 0],
    'blue': [0, 0, 0, 0],
  };

  @override
  void initState() {
    super.initState();
    initSocket();
  }

  void initSocket() {
    socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
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
    double boardSize = MediaQuery.of(context).size.width - 32;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ludo Billionaires',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Complete Ludo Board with Grid and Home Boxes
          Center(
            child: Container(
              width: boardSize,
              height: boardSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: Stack(
                children: [
                  // 15x15 Full Board Grid Path
                  SizedBox(
                    width: boardSize,
                    height: boardSize,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 225,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 15,
                      ),
                      itemBuilder: (context, index) {
                        int row = index ~/ 15;
                        int col = index % 15;
                        return _buildCell(row, col);
                      },
                    ),
                  ),

                  // 4 Corner Home Bases Overlay
                  Positioned(top: 0, left: 0, child: _buildHomeBase(Colors.red, boardSize, 'red')),
                  Positioned(top: 0, right: 0, child: _buildHomeBase(Colors.green, boardSize, 'green')),
                  Positioned(bottom: 0, left: 0, child: _buildHomeBase(Colors.blue, boardSize, 'blue')),
                  Positioned(bottom: 0, right: 0, child: _buildHomeBase(Colors.yellow, boardSize, 'yellow')),

                  // Center Triangle
                  Positioned(
                    top: boardSize * 0.4,
                    left: boardSize * 0.4,
                    child: Container(
                      width: boardSize * 0.2,
                      height: boardSize * 0.2,
                      color: Colors.amber[800],
                      child: const Icon(Icons.star, color: Colors.white, size: 36),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dice Roller Section
          GestureDetector(
            onTap: rollDice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  const SizedBox(height: 6),
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '$diceValue',
                        style: const TextStyle(
                          fontSize: 30,
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

  // Colored Home Base with 4 Pawns
  Widget _buildHomeBase(Color color, double boardSize, String colorKey) {
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
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  // Path Grid Cells and Colored Tracks
  Widget _buildCell(int row, int col) {
    Color cellColor = Colors.white;

    // Green Path
    if (row == 7 && col > 0 && col < 6) cellColor = Colors.green;
    if (row == 6 && col == 1) cellColor = Colors.green;

    // Red Path
    if (col == 7 && row > 0 && row < 6) cellColor = Colors.red;
    if (row == 1 && col == 8) cellColor = Colors.red;

    // Yellow Path
    if (col == 7 && row > 8 && row < 14) cellColor = Colors.yellow;
    if (row == 13 && col == 6) cellColor = Colors.yellow;

    // Blue Path
    if (row == 7 && col > 8 && col < 14) cellColor = Colors.blue;
    if (row == 8 && col == 13) cellColor = Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        border: Border.all(color: Colors.grey[400]!, width: 0.5),
      ),
    );
  }
}
