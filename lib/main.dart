import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await notifications.initialize(initSettings);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viikkotehtävät',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const TasksPage(),
    );
  }
}

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  CollectionReference<Map<String, dynamic>> get tasks =>
      FirebaseFirestore.instance.collection('tasks');

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    String selectedDay = 'Maanantai';
    String selectedType = 'Muut';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lisää tehtävä'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Tehtävän nimi'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDay,
                items: const [
                  DropdownMenuItem(value: 'Maanantai', child: Text('Maanantai')),
                  DropdownMenuItem(value: 'Tiistai', child: Text('Tiistai')),
                  DropdownMenuItem(
                      value: 'Keskiviikko', child: Text('Keskiviikko')),
                  DropdownMenuItem(value: 'Torstai', child: Text('Torstai')),
                  DropdownMenuItem(
                      value: 'Perjantai', child: Text('Perjantai')),
                ],
                onChanged: (value) {
                  if (value != null) selectedDay = value;
                },
                decoration: const InputDecoration(labelText: 'Päivä'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'Tentti', child: Text('Tentti')),
                  DropdownMenuItem(value: 'Projekti', child: Text('Projekti')),
                  DropdownMenuItem(value: 'Muut', child: Text('Muut')),
                ],
                onChanged: (value) {
                  if (value != null) selectedType = value;
                },
                decoration: const InputDecoration(labelText: 'Tyyppi'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Peruuta'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('tasks').add({
                  'title': titleController.text.trim(),
                  'day': selectedDay,
                  'time': '14:00',
                  'type': selectedType,
                  'done': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              },
              child: const Text('Tallenna'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tehtävät')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tasks.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Virhe: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Ei tehtäviä vielä. Paina +'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final title = (data['title'] ?? '').toString();
              final day = (data['day'] ?? '').toString();
              final time = (data['time'] ?? '').toString();
              final type = (data['type'] ?? '').toString();

              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('$day • $time • $type'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
