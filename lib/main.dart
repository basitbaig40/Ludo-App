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

  // Token positions (-1 = Inside Home Base, 0 to 50 = Main Path, 51 to 56 = Home Path)
  Map<PlayerColor, List<int>> tokenPositions = {
    PlayerColor.red: [-1, -1, -1, -1],
    PlayerColor.green: [-1, -1, -1, -1],
    PlayerColor.yellow: [-1, -1, -1, -1],
    PlayerColor.blue: [-1, -1, -1, -1],
  };

  // 52 Main Track Path Coordinates (row, col)
  final List<Point<int>> mainPath = const [
    Point(6, 1), Point(6, 2), Point(6, 3), Point(6, 4), Point(6, 5),
    Point(5, 6), Point(4, 6), Point(3, 6), Point(2, 6), Point(1, 6), Point(0, 6),
    Point(0, 7), Point(0, 8),
    Point(1, 8), Point(2, 8), Point(3, 8), Point(4, 8), Point(5, 8),
    Point(6, 9), Point(6, 10), Point(6, 11), Point(6, 12), Point(6, 13), Point(6, 14),
    Point(7, 14), Point(8, 14),
    Point(8, 13), Point(8, 12), Point(8, 11), Point(8, 10), Point(8, 9),
    Point(9, 8), Point(10, 8), Point(11, 8), Point(12, 8), Point(13, 8), Point(14, 8),
    Point(14, 7), Point(14, 6),
    Point(13, 6), Point(12, 6), Point(11, 6), Point(10, 6), Point(9, 6),
    Point(8, 5), Point(8, 4), Point(8, 3), Point(8, 2), Point(8, 1), Point(8, 0),
    Point(7, 0), Point(6, 0)
  ];

  // Custom Safe Spots (Point(row, col))
  final Set<Point<int>> safeSpots = const {
    Point(2, 6),   // Top-Left (Near Green)
    Point(6, 12),  // Top-Right (Near Yellow)
    Point(12, 8),  // Bottom-Right (Near Blue)
    Point(8, 2),   // Bottom-Left (Near Red)
  };

  // Home Path (Inner Colored Track leading to Center Home)
  final Map<PlayerColor, List<Point<int>>> homePaths = const {
    PlayerColor.red: [
      Point(7, 1), Point(7, 2), Point(7, 3), Point(7, 4), Point(7, 5), Point(7, 6)
    ],
    PlayerColor.green: [
      Point(1, 7), Point(2, 7), Point(3, 7), Point(4, 7), Point(5, 7), Point(6, 7)
    ],
    PlayerColor.yellow: [
      Point(7, 13), Point(7, 12), Point(7, 11), Point(7, 10), Point(7, 9), Point(7, 8)
    ],
    PlayerColor.blue: [
      Point(13, 7), Point(12, 7), Point(11, 7), Point(10, 7), Point(9, 7), Point(8, 7)
    ],
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

    // Unlock Goti on 6
    if (currentPos == -1) {
      if (diceValue == 6) {
        setState(() {
          tokens[tokenIndex] = 0;
          hasRolled = false;
        });
      }
      return;
    }

    // Move Forward
    if (currentPos + diceValue <= 56) {
      int newPos = currentPos + diceValue;
      bool killedOpponent = _checkAndKill(currentTurn, newPos);

      setState(() {
        tokens[tokenIndex] = newPos;
        hasRolled = false;
      });

      // Bonus Turn on 6 or on Killing an Opponent
      if (diceValue == 6 || killedOpponent) return;

      _nextTurn();
    }
  }

  // Kill Logic
  bool _checkAndKill(PlayerColor player, int newPos) {
    if (newPos > 50) return false;

    Point<int>? targetCoord = _getTokenCoordinate(player, newPos);
    if (targetCoord == null) return false;

    if (safeSpots.contains(targetCoord)) return false;

    bool killed = false;

    tokenPositions.forEach((oppColor, oppTokens) {
      if (oppColor != player) {
        for (int i = 0; i < oppTokens.length; i++) {
          int oppPos = oppTokens[i];
          if (oppPos >= 0 && oppPos <= 50) {
            Point<int>? oppCoord = _getTokenCoordinate(oppColor, oppPos);
            if (oppCoord == targetCoord) {
              oppTokens[i] = -1;
              killed = true;
            }
          }
        }
      }
    });

    return killed;
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

  Point<int>? _getTokenCoordinate(PlayerColor color, int pos) {
    if (pos < 0 || pos > 56) return null;

    int offset = 0;
    if (color == PlayerColor.red) offset = 0;
    if (color == PlayerColor.green) offset = 13;
    if (color == PlayerColor.yellow) offset = 26;
    if (color == PlayerColor.blue) offset = 39;

    if (pos > 50) {
      int homeIdx = pos - 51;
      return homePaths[color]![homeIdx];
    }

    int pathIdx = (pos + offset) % 52;
    return mainPath[pathIdx];
  }

  @override
  Widget build(BuildContext context) {
    double boardSize = MediaQuery.of(context).size.width - 24;
    double cellSize = boardSize / 15;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Billionaires', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Turn Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _getPlayerColorHex(currentTurn).withOpacity(0.15),
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
                  // Grid Cells
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

                  // 4 Home Bases
                  Positioned(top: 0, left: 0, child: _buildHomeBase(Colors.red, boardSize, PlayerColor.red)),
                  Positioned(top: 0, right: 0, child: _buildHomeBase(Colors.green, boardSize, PlayerColor.green)),
                  Positioned(bottom: 0, left: 0, child: _buildHomeBase(Colors.blue, boardSize, PlayerColor.blue)),
                  Positioned(bottom: 0, right: 0, child: _buildHomeBase(Colors.amber[700]!, boardSize, PlayerColor.yellow)),

                  // Center Logo (Golden Crown + Crypto Dice + Title)
                  Positioned(
                    top: boardSize * 0.4,
                    left: boardSize * 0.4,
                    child: Container(
                      width: boardSize * 0.2,
                      height: boardSize * 0.2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Crown Icon
                              const Icon(
                                Icons.workspace_premium,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                              const SizedBox(height: 2),

                              // Crypto Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber[700],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₿',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.casino,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),

                              // Title Text
                              const Text(
                                'LUDO',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'BILLIONAIRES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 6,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Active Pawns
                  ..._buildBoardTokens(cellSize),
                ],
              ),
            ),
          ),

          // Dice Control
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
                    isRolling ? 'Rolling...' : (hasRolled ? 'Tap Pawn to Move' : 'Tap to Roll'),
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

  List<Widget> _buildBoardTokens(double cellSize) {
    List<Widget> widgets = [];
    tokenPositions.forEach((player, tokens) {
      for (int i = 0; i < tokens.length; i++) {
        int pos = tokens[i];
        Point<int>? point = _getTokenCoordinate(player, pos);
        if (point != null) {
          widgets.add(
            Positioned(
              left: point.y * cellSize + 2,
              top: point.x * cellSize + 2,
              child: GestureDetector(
                onTap: () {
                  if (currentTurn == player) moveToken(i);
                },
                child: Container(
                  width: cellSize - 4,
                  height: cellSize - 4,
                  decoration: BoxDecoration(
                    color: _getPlayerColorHex(player),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                  ),
                  child: const Center(
                    child: Icon(Icons.stars, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ),
          );
        }
      }
    });
    return widgets;
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
                    boxShadow: inBase ? [const BoxShadow(color: Colors.black26, blurRadius: 2)] : [],
                  ),
                  child: Icon(
                    Icons.directions_walk,
                    color: inBase ? Colors.white : Colors.grey[500],
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

    // Home Path Colors
    if (row == 7 && col > 0 && col < 6) cellColor = Colors.red;
    if (row == 6 && col == 1) cellColor = Colors.red;

    if (col == 7 && row > 0 && row < 6) cellColor = Colors.green;
    if (row == 1 && col == 8) cellColor = Colors.green;

    if (row == 7 && col > 8 && col < 14) cellColor = Colors.amber[700]!;
    if (row == 8 && col == 13) cellColor = Colors.amber[700]!;

    if (col == 7 && row > 8 && row < 14) cellColor = Colors.blue;
    if (row == 13 && col == 6) cellColor = Colors.blue;

    // Safe Spot check
    bool isSafeSpot = safeSpots.contains(Point(row, col));

    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: isSafeSpot
          ? Icon(
              Icons.star,
              color: cellColor == Colors.white ? Colors.amber[800] : Colors.white,
              size: 16,
            )
          : null,
    );
  }
}
