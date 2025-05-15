import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const GuessGameApp());

class GuessGameApp extends StatelessWidget {
  const GuessGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeu de Devinette',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const GuessGamePage(),
    );
  }
}

class GuessGamePage extends StatefulWidget {
  const GuessGamePage({super.key});

  @override
  State<GuessGamePage> createState() => _GuessGamePageState();
}

class _GuessGamePageState extends State<GuessGamePage> {
  final TextEditingController _controller = TextEditingController();
  final int _maxAttempts = 5;
  int _target = 0;
  int _attempts = 0;
  int _score = 0;
  int _seconds = 0;
  bool _gameOver = false;
  String _message = '';
  Stopwatch _timer = Stopwatch();
  List<Map<String, dynamic>> _history = [];

  // Stocke la liste des scores récupérés
  List<Map<String, dynamic>> _scores = [];

  // 👇 Remplace par la bonne URL selon ton environnement !
  final String _apiUrl = 'http://10.0.2.2:3000/scores'; // Android Emulator

  void _startGame() {
    setState(() {
      _target = Random().nextInt(100) + 1; // nombre entre 1 et 100
      _attempts = 0;
      _score = 0;
      _gameOver = false;
      _message = '';
      _history.clear();
      _controller.clear();
      _seconds = 0;
      _timer.reset();
      _timer.start();
    });
  }

  void _check() {
    if (_gameOver) return;

    final input = int.tryParse(_controller.text);
    if (input == null) {
      setState(() {
        _message = 'Veuillez entrer un nombre valide';
      });
      return;
    }

    if (input < 1 || input > 100) {
      setState(() {
        _message = 'Le nombre doit être entre 1 et 100';
        _controller.clear();
      });
      return;
    }

    setState(() {
      _attempts++;
      String feedback;

      if (input < _target) {
        feedback = 'Plus grand';
      } else if (input > _target) {
        feedback = 'Plus petit';
      } else {
        feedback = 'Bravo !';
        _gameOver = true;
        _timer.stop();
        _seconds = _timer.elapsed.inSeconds;
        _score = (6 - _attempts) * 10;
        _showNameDialog();
      }

      _history.add({
        "tentative": _attempts,
        "proposition": input,
        "message": feedback,
      });

      if (!_gameOver && _attempts >= _maxAttempts) {
        _gameOver = true;
        _timer.stop();
        _seconds = _timer.elapsed.inSeconds;
        _message = 'Perdu ! Le nombre était $_target';
      } else {
        _message = feedback;
      }

      _controller.clear();
    });
  }

  Future<void> _sendScoreToServer(String name) async {
    final scoreData = {
      "name": name,
      "score": _score,
      "time": _seconds,
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(scoreData),
      );

      if (response.statusCode == 201) {
        print("✅ Score envoyé avec succès !");
      } else {
        print("❌ Erreur serveur: ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur réseau : $e");
    }
  }

  void _showNameDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Félicitations !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score : $_score'),
            Text('Temps : $_seconds s'),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Votre nom'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              String name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _sendScoreToServer(name);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez entrer votre nom')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // Récupérer la liste des scores depuis le serveur
  Future<void> _fetchScores() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _scores = data.cast<Map<String, dynamic>>();
        });
        _showScoresDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur serveur: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    }
  }

  // Affiche une boîte de dialogue avec la liste des scores
  void _showScoresDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🏆 Scores'),
        content: SizedBox(
          width: double.maxFinite,
          child: _scores.isEmpty
              ? const Text('Aucun score enregistré')
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _scores.length,
            itemBuilder: (context, index) {
              final score = _scores[index];
              return ListTile(
                title: Text('${score["name"]} : ${score["score"]} pts'),
                subtitle: Text('Temps : ${score["time"]} s'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎯 Jeu de Devinette')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: _startGame,
              label: const Text('Nouveau Jeu'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.leaderboard),
              onPressed: _fetchScores,
              label: const Text('Voir Scores'),
            ),
            const SizedBox(height: 20),
            if (_target != 0) ...[
              Text('Tentative : $_attempts / $_maxAttempts'),
              const SizedBox(height: 10),
              Text('Temps : $_seconds s'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      enabled: !_gameOver,
                      decoration: const InputDecoration(
                        labelText: 'Entrez un nombre (1-100)',
                      ),
                      onSubmitted: (_) => _check(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _gameOver ? null : _check,
                    child: const Text('Valider'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _message,
                style: const TextStyle(fontSize: 18, color: Colors.tealAccent),
              ),
              const SizedBox(height: 10),
              if (_history.isNotEmpty) ...[
                const Text('Historique des tentatives :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return ListTile(
                        leading: Text('Essai ${item["tentative"]}'),
                        title:
                        Text('Vous avez proposé : ${item["proposition"]}'),
                        subtitle: Text('Indice : ${item["message"]}'),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
