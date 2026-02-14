import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

  // Päiväjärjestys
  int dayIndex(String day) => const {
        'Maanantai': 0,
        'Tiistai': 1,
        'Keskiviikko': 2,
        'Torstai': 3,
        'Perjantai': 4,
        'Lauantai': 5,
        'Sunnuntai': 6,
      }[day] ??
      99;

  // Aika → minuutit
  int timeToMinutes(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return h * 60 + m;
  }

  // 🎨 Pastelliväri per päivä (kevyt ja selkeä mobiilissa)
  Color dayColor(String day) => const {
        'Maanantai': Color(0xFFE3F2FD), // vaalea sininen
        'Tiistai': Color(0xFFE8F5E9), // vaalea vihreä
        'Keskiviikko': Color(0xFFFFF3E0), // vaalea oranssi
        'Torstai': Color(0xFFF3E5F5), // vaalea violetti
        'Perjantai': Color(0xFFFFEBEE), // vaalea punainen/pinkki
        'Lauantai': Color(0xFFE0F7FA), // vaalea turkoosi
        'Sunnuntai': Color(0xFFFFFDE7), // vaalea keltainen
      }[day] ??
      const Color(0xFFF5F5F5);

  Color dayAccent(String day) => const {
        'Maanantai': Color(0xFF42A5F5),
        'Tiistai': Color(0xFF66BB6A),
        'Keskiviikko': Color(0xFFFFA726),
        'Torstai': Color(0xFFAB47BC),
        'Perjantai': Color(0xFFEF5350),
        'Lauantai': Color(0xFF26C6DA),
        'Sunnuntai': Color(0xFFFDD835),
      }[day] ??
      const Color(0xFF9E9E9E);

  // ✅ Poista KAIKKI tehdyt (kaikilta päiviltä) batchina
  Future<void> _deleteAllDoneTasks(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tyhjennä kaikki tehdyt?'),
        content: const Text(
          'Poistetaan kaikki tehdyt tehtävät kaikilta päiviltä. Tätä ei voi perua.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Peruuta'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Poista kaikki'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final snapshot = await tasks.where('done', isEqualTo: true).get();
    if (snapshot.docs.isEmpty) return;

    // Firestore batch max 500 operaatiota / batch
    const batchLimit = 500;
    for (var i = 0; i < snapshot.docs.length; i += batchLimit) {
      final chunk = snapshot.docs.skip(i).take(batchLimit);
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in chunk) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    String selectedDay = 'Maanantai';
    String selectedType = 'Muut';
    String selectedTime = '14:00';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Lisää tehtävä'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Tehtävän nimi'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      items: const [
                        DropdownMenuItem(
                            value: 'Maanantai', child: Text('Maanantai')),
                        DropdownMenuItem(
                            value: 'Tiistai', child: Text('Tiistai')),
                        DropdownMenuItem(
                            value: 'Keskiviikko', child: Text('Keskiviikko')),
                        DropdownMenuItem(
                            value: 'Torstai', child: Text('Torstai')),
                        DropdownMenuItem(
                            value: 'Perjantai', child: Text('Perjantai')),
                        DropdownMenuItem(
                            value: 'Lauantai', child: Text('Lauantai')),
                        DropdownMenuItem(
                            value: 'Sunnuntai', child: Text('Sunnuntai')),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedDay = value ?? selectedDay),
                      decoration: const InputDecoration(labelText: 'Päivä'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'Tentti', child: Text('Tentti')),
                        DropdownMenuItem(
                            value: 'Projekti', child: Text('Projekti')),
                        DropdownMenuItem(value: 'Muut', child: Text('Muut')),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedType = value ?? selectedType),
                      decoration: const InputDecoration(labelText: 'Tyyppi'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Aika',
                        hintText: selectedTime,
                        suffixIcon: const Icon(Icons.access_time),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          final hh = picked.hour.toString().padLeft(2, '0');
                          final mm = picked.minute.toString().padLeft(2, '0');
                          setState(() => selectedTime = '$hh:$mm');
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Peruuta'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    Navigator.pop(context); // ✅ sulje heti

                    await tasks.add({
                      'title': title,
                      'day': selectedDay,
                      'time': selectedTime,
                      'type': selectedType,
                      'done': false,
                      'dayIndex': dayIndex(selectedDay),
                      'timeMinutes': timeToMinutes(selectedTime),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  },
                  child: const Text('Tallenna'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTaskDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final titleController =
        TextEditingController(text: (data['title'] ?? '').toString());
    String selectedDay = (data['day'] ?? 'Maanantai').toString();
    String selectedType = (data['type'] ?? 'Muut').toString();
    String selectedTime = (data['time'] ?? '14:00').toString();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Muokkaa tehtävää'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Tehtävän nimi'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      items: const [
                        DropdownMenuItem(
                            value: 'Maanantai', child: Text('Maanantai')),
                        DropdownMenuItem(
                            value: 'Tiistai', child: Text('Tiistai')),
                        DropdownMenuItem(
                            value: 'Keskiviikko', child: Text('Keskiviikko')),
                        DropdownMenuItem(
                            value: 'Torstai', child: Text('Torstai')),
                        DropdownMenuItem(
                            value: 'Perjantai', child: Text('Perjantai')),
                        DropdownMenuItem(
                            value: 'Lauantai', child: Text('Lauantai')),
                        DropdownMenuItem(
                            value: 'Sunnuntai', child: Text('Sunnuntai')),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedDay = value ?? selectedDay),
                      decoration: const InputDecoration(labelText: 'Päivä'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'Tentti', child: Text('Tentti')),
                        DropdownMenuItem(
                            value: 'Projekti', child: Text('Projekti')),
                        DropdownMenuItem(value: 'Muut', child: Text('Muut')),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedType = value ?? selectedType),
                      decoration: const InputDecoration(labelText: 'Tyyppi'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Aika',
                        hintText: selectedTime,
                        suffixIcon: const Icon(Icons.access_time),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          final hh = picked.hour.toString().padLeft(2, '0');
                          final mm = picked.minute.toString().padLeft(2, '0');
                          setState(() => selectedTime = '$hh:$mm');
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context); // ✅ sulje heti
                    await tasks.doc(docId).delete();
                  },
                  child:
                      const Text('Poista', style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Peruuta'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // ✅ sulje heti
                    await tasks.doc(docId).update({
                      'title': titleController.text.trim(),
                      'day': selectedDay,
                      'time': selectedTime,
                      'type': selectedType,
                      'dayIndex': dayIndex(selectedDay),
                      'timeMinutes': timeToMinutes(selectedTime),
                    });
                  },
                  child: const Text('Tallenna'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dayHeader(String day) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: dayColor(day),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        day,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _doneHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Tehdyt',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          TextButton.icon(
            onPressed: () => _deleteAllDoneTasks(context),
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Tyhjennä kaikki'),
          ),
        ],
      ),
    );
  }

  Widget _taskCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> data,
    required bool doneValue,
  }) {
    final day = (data['day'] ?? '').toString();
    final accent = dayAccent(day);

    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accent, width: 5),
          ),
        ),
        child: ListTile(
          title: Text(
            (data['title'] ?? '').toString(),
            style: TextStyle(
              decoration: doneValue ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            '${(data['time'] ?? '').toString()} • ${(data['type'] ?? '').toString()}',
          ),
          trailing: Checkbox(
            value: doneValue,
            onChanged: (v) => tasks.doc(doc.id).update({'done': v}),
          ),
          onTap: () => _showEditTaskDialog(context, doc.id, data),
        ),
      ),
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
        stream: tasks.orderBy('dayIndex').orderBy('timeMinutes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Virhe: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;

          final undoneDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final doneDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (final d in allDocs) {
            final data = d.data();
            final done = data['done'] ?? false;
            if (done == true) {
              doneDocs.add(d);
            } else {
              undoneDocs.add(d);
            }
          }

          final widgets = <Widget>[];

          // ---- Tekemättömät ----
          if (undoneDocs.isEmpty) {
            widgets.add(const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Ei keskeneräisiä tehtäviä 👍'),
            ));
          } else {
            String? lastDay;
            for (final doc in undoneDocs) {
              final data = doc.data();
              final day = (data['day'] ?? '').toString();
              final showHeader = day.isNotEmpty && day != lastDay;
              lastDay = day;

              if (showHeader) widgets.add(_dayHeader(day));

              widgets.add(
                _taskCard(
                  context: context,
                  doc: doc,
                  data: data,
                  doneValue: false,
                ),
              );
            }
          }

          // ---- Tehdyt ----
          if (doneDocs.isNotEmpty) {
            widgets.add(_doneHeaderRow(context));

            String? lastDayDone;
            for (final doc in doneDocs) {
              final data = doc.data();
              final day = (data['day'] ?? '').toString();
              final showHeader = day.isNotEmpty && day != lastDayDone;
              lastDayDone = day;

              if (showHeader) {
                widgets.add(Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dayAccent(day),
                    ),
                  ),
                ));
              }

              widgets.add(
                _taskCard(
                  context: context,
                  doc: doc,
                  data: data,
                  doneValue: true,
                ),
              );
            }
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widgets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => widgets[i],
          );
        },
      ),
    );
  }
}
