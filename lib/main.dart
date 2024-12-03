import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const QuizSetupScreen(),
    );
  }
}

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  _QuizSetupScreenState createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  List categories = [];
  int selectedCategory = 0;
  String selectedDifficulty = 'easy';
  String selectedType = 'multiple';
  int numberOfQuestions = 5;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final response =
        await http.get(Uri.parse('https://opentdb.com/api_category.php'));
    if (response.statusCode == 200) {
      setState(() {
        categories = json.decode(response.body)['trivia_categories'];
      });
    }
  }

  void startQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          categoryId: selectedCategory,
          difficulty: selectedDifficulty,
          type: selectedType,
          numberOfQuestions: numberOfQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Setup')),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map<DropdownMenuItem<int>>(
                          (category) => DropdownMenuItem<int>(
                            value: category['id'],
                            child: Text(category['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    value: selectedDifficulty,
                    items: ['easy', 'medium', 'hard']
                        .map((difficulty) => DropdownMenuItem<String>(
                              value: difficulty,
                              child: Text(difficulty),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDifficulty = value!;
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Type'),
                    value: selectedType,
                    items: ['multiple', 'boolean']
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  Slider(
                    value: numberOfQuestions.toDouble(),
                    min: 5,
                    max: 15,
                    divisions: 2,
                    label: '$numberOfQuestions',
                    onChanged: (value) {
                      setState(() {
                        numberOfQuestions = value.toInt();
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: startQuiz,
                    child: const Text('Start Quiz'),
                  ),
                ],
              ),
            ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final int categoryId;
  final String difficulty;
  final String type;
  final int numberOfQuestions;

  const QuizScreen({super.key, 
    required this.categoryId,
    required this.difficulty,
    required this.type,
    required this.numberOfQuestions,
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List questions = [];
  List<List<String>> shuffledAnswers = [];
  int currentQuestionIndex = 0;
  int score = 0;
  String feedback = '';
  Timer? timer;
  int timeLeft = 15;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
  final response = await http.get(Uri.parse(
      'https://opentdb.com/api.php?amount=${widget.numberOfQuestions}&category=${widget.categoryId}&difficulty=${widget.difficulty}&type=${widget.type}'));
  if (response.statusCode == 200) {
    final fetchedQuestions = json.decode(response.body)['results'];
    setState(() {
      questions = fetchedQuestions;
      shuffledAnswers = fetchedQuestions.map<List<String>>((question) {
        final answers = [
          ...question['incorrect_answers'],
          question['correct_answer']
        ];
        answers.shuffle();
        return answers.cast<String>();
      }).toList();
      startTimer();
    });
  }
}

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft == 0) {
        setState(() {
          feedback = "Time's up!";
          nextQuestion();
        });
        timer.cancel();
      } else {
        setState(() {
          timeLeft--;
        });
      }
    });
  }

  void checkAnswer(String selectedAnswer) {
    timer?.cancel();
    final correctAnswer = questions[currentQuestionIndex]['correct_answer'];
    if (selectedAnswer == correctAnswer) {
      setState(() {
        score++;
        feedback = 'Correct!';
      });
    } else {
      setState(() {
        feedback = 'Incorrect! Correct answer: $correctAnswer';
      });
    }
    nextQuestion();
  }

  void nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        timeLeft = 15;
        feedback = '';
        startTimer();
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SummaryScreen(score: score, questions: questions),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final question = questions[currentQuestionIndex];
    final answers = shuffledAnswers[currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Score: $score'),
            Text('Time left: $timeLeft'),
            LinearProgressIndicator(
                value: currentQuestionIndex / questions.length),
            const SizedBox(height: 20),
            Text(question['question']),
            const SizedBox(height: 20),
            ...answers.map((answer) => ElevatedButton(
                  onPressed: () => checkAnswer(answer),
                  child: Text(answer),
                )),
            const SizedBox(height: 20),
            Text(feedback),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}


class SummaryScreen extends StatelessWidget {
  final int score;
  final List questions;

  const SummaryScreen({super.key, required this.score, required this.questions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Total Score: $score'),
            Expanded(
              child: ListView.builder(
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return ListTile(
                    title: Text(decodeHtml(question['question'])),
                    subtitle: Text('Correct Answer: ${decodeHtml(question['correct_answer'])}'),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Retake Quiz'),
            ),
          ],
        ),
      ),
    );
  }

  String decodeHtml(String htmlString) {
    return parse(htmlString).body!.text;
  }
}
