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

enum PlayerColor { red, green, yellow, blue }

class _LudoBoardScreenState extends State<LudoBoardScreen> {
  int diceValue = 1;
  bool isRolling = false;
  bool hasRolled = false;
  PlayerColor currentTurn = PlayerColor.red;
  late IO.Socket socket;

  // Token positions (-1 = Home Base, 0 to 50 = Main Track, 51-56 = Home Path)
  Map<PlayerColor, List<int>> tokenPositions = {
    PlayerColor.red: [-1, -1, -1, -1],
    PlayerColor.green: [-1, -1, -1, -1],
    PlayerColor.yellow: [-1, -1, -1, -1],
    PlayerColor.blue: [-1, -1, -1, -1],
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
    if (isRolling || hasRolled) return;
    setState(() => isRolling = true);

    int rolls = 0;
    Timer.periodic(const Duration(milliseconds: 90), (timer) {
      setState(() {
        diceValue = Random().nextInt(6) + 1;
      });
      rolls++;
      if (rolls >= 8) {
        timer.cancel();
        setState(() {
          isRolling = false;
          hasRolled = true;
        });

        // Check if player has any playable moves
        if (!_canPlayerMove()) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _nextTurn();
          });
        }
      }
    });
  }

  bool _canPlayerMove() {
    List<int> currentTokens = tokenPositions[currentTurn]!;
    if (diceValue == 6) return true;
    return currentTokens.any((pos) => pos >= 0 && pos + diceValue <= 56);
  }

  void moveToken(int tokenIndex) {
    if (!hasRolled || isRolling) return;

    List<int> tokens = tokenPositions[currentTurn]!;
    int currentPos = tokens[tokenIndex];

    // Token inside Home Base (Requires 6 to unlock)
    if (currentPos == -1) {
      if (diceValue == 6) {
        setState(() {
          tokens[tokenIndex] = 0;
          hasRolled = false;
        });
      }
      return;
    }

    // Token on Track
    if (currentPos + diceValue <= 56) {
      setState(() {
        tokens[tokenIndex] += diceValue;
        hasRolled = false;
      });

      // Bonus Turn on rolling 6
      if (diceValue == 6) {
        return;
      }

      _nextTurn();
    }
  }

  void _nextTurn() {
    setState(() {
      hasRolled = false;
      switch (currentTurn) {
        case PlayerColor.red:
          currentTurn = PlayerColor.green;
          break;
        case PlayerColor.green:
          currentTurn = PlayerColor.yellow;
          break;
        case PlayerColor.yellow:
          currentTurn = PlayerColor.blue;
          break;
        case PlayerColor.blue:
          currentTurn = PlayerColor.red;
          break;
      }
    });
  }

  Color _getPlayerColorHex(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return Colors.red;
      case PlayerColor.green:
        return Colors.green;
      case PlayerColor.yellow:
        return Colors.amber[700]!;
      case PlayerColor.blue:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    double boardSize = MediaQuery.of(context).size.width - 24;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Billionaires', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Current Turn Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getPlayerColorHex(currentTurn).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getPlayerColorHex(currentTurn), width: 2),
            ),
            child: Text(
              'Turn: ${currentTurn.name.toUpperCase()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getPlayerColorHex(currentTurn),
              ),
            ),
          ),

          // Ludo Board
          Center(
            child: Container(
              width: boardSize,
              height: boardSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: Stack(
                children: [
                  // Grid Track
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

                  // Bases
                  Positioned(top: 0, left: 0, child: _buildHomeBase(Colors.red, boardSize, PlayerColor.red)),
                  Positioned(top: 0, right: 0, child: _buildHomeBase(Colors.green, boardSize, PlayerColor.green)),
                  Positioned(bottom: 0, left: 0, child: _buildHomeBase(Colors.blue, boardSize, PlayerColor.blue)),
                  Positioned(bottom: 0, right: 0, child: _buildHomeBase(Colors.yellow, boardSize, PlayerColor.yellow)),

                  // Center Triangle Home
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

          // Dice Roller Controls
          GestureDetector(
            onTap: rollDice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _getPlayerColorHex(currentTurn),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Column(
                children: [
                  Text(
                    isRolling ? 'Rolling...' : (hasRolled ? 'Select Pawn' : 'Tap to Roll'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$diceValue',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _getPlayerColorHex(currentTurn),
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

  Widget _buildHomeBase(Color color, double boardSize, PlayerColor playerKey) {
    double baseSize = boardSize * 0.4;
    List<int> tokens = tokenPositions[playerKey]!;

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
            (index) {
              bool inBase = tokens[index] == -1;
              return GestureDetector(
                onTap: () {
                  if (currentTurn == playerKey && inBase) {
                    moveToken(index);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: inBase ? color : Colors.grey[300],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Icon(
                    Icons.person,
                    color: inBase ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    Color cellColor = Colors.white;

    // Green Path & Home Trail
    if (row == 7 && col > 0 && col < 6) cellColor = Colors.green;
    if (row == 6 && col == 1) cellColor = Colors.green;

    // Red Path & Home Trail
    if (col == 7 && row > 0 && row < 6) cellColor = Colors.red;
    if (row == 1 && col == 8) cellColor = Colors.red;

    // Yellow Path & Home Trail
    if (col == 7 && row > 8 && row < 14) cellColor = Colors.yellow;
    if (row == 13 && col == 6) cellColor = Colors.yellow;

    // Blue Path & Home Trail
    if (row == 7 && col > 8 && col < 14) cellColor = Colors.blue;
    if (row == 8 && col == 13) cellColor = Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
    );
  }
}
