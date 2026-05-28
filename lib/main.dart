import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoApp());
}

class TodoItem {
  TodoItem({
    required this.title,
    this.isDone = false,
  });

  final String title;
  bool isDone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'isDone': isDone,
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      title: (json['title'] as String?) ?? '',
      isDone: (json['isDone'] as bool?) ?? false,
    );
  }
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  static const String _tasksKey = 'tasks';
  static const String _darkModeKey = 'darkMode';

  final List<TodoItem> _todos = <TodoItem>[];
  final TextEditingController _controller = TextEditingController();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> storedTasks = prefs.getStringList(_tasksKey) ?? <String>[];
    final bool storedDarkMode = prefs.getBool(_darkModeKey) ?? false;

    final List<TodoItem> parsedTodos = storedTasks
        .map(
          (String raw) =>
              TodoItem.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        )
        .toList();

    setState(() {
      _todos
        ..clear()
        ..addAll(parsedTodos);
      _isDarkMode = storedDarkMode;
    });
  }

  Future<void> _saveTasks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> serialized = _todos
        .map((TodoItem item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList(_tasksKey, serialized);
  }

  Future<void> _saveDarkMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTask() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _todos.add(TodoItem(title: text));
    });
    _controller.clear();
    _saveTasks();
  }

  void _toggleTask(int index, bool? value) {
    setState(() {
      _todos[index].isDone = value ?? false;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _todos.removeAt(index);
    });
    _saveTasks();
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _saveDarkMode();
  }

  int get _completedCount =>
      _todos.where((TodoItem t) => t.isDone).length;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        ),
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('📝 To-Do'),
              if (_todos.isNotEmpty)
                Text(
                  '$_completedCount of ${_todos.length} done',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
            ],
          ),
          actions: <Widget>[
            if (_completedCount > 0)
              TextButton(
                onPressed: () {
                  setState(() {
                    _todos.removeWhere((TodoItem t) => t.isDone);
                  });
                  _saveTasks();
                },
                child: const Text('Clear completed'),
              ),
            IconButton(
              onPressed: _toggleDarkMode,
              icon: Icon(
                _isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
              tooltip: _isDarkMode ? 'Light mode' : 'Dark mode',
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: _todos.isEmpty
                  ? const Center(child: Text('No tasks yet'))
                  : ListView.builder(
                      itemCount: _todos.length,
                      itemBuilder: (BuildContext context, int index) {
                        final TodoItem todo = _todos[index];
                        return Column(
                          children: <Widget>[
                            ListTile(
                              leading: Checkbox(
                                value: todo.isDone,
                                onChanged: (bool? value) =>
                                    _toggleTask(index, value),
                              ),
                              title: Text(
                                todo.title,
                                style: TextStyle(
                                  decoration: todo.isDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: todo.isDone
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5)
                                      : null,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteTask(index),
                              ),
                            ),
                            const Divider(height: 0),
                          ],
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _addTask(),
                        decoration: const InputDecoration(
                          hintText: 'Add a task',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addTask,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
