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

class _TodoAppState extends State<TodoApp> with SingleTickerProviderStateMixin {
  static const String _tasksKey = 'tasks';
  static const String _darkModeKey = 'darkMode';
  static const Color _bgColor = Color(0xFF0A0A0A);
  static const Color _cardColor = Color(0xFF111111);
  static const Color _accentColor = Color(0xFF00FF88);
  static const Color _activeTextColor = Color(0xFFFFFFFF);
  static const Color _completedTextColor = Color(0xFF8A8A8A);

  final List<TodoItem> _todos = <TodoItem>[];
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _isDarkMode = false;
  bool _isInputFocused = false;
  late final AnimationController _addButtonController;
  late final Animation<double> _addButtonScale;

  @override
  void initState() {
    super.initState();
    _addButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _addButtonScale = Tween<double>(begin: 1, end: 0.93).animate(
      CurvedAnimation(
        parent: _addButtonController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _inputFocusNode.addListener(() {
      setState(() {
        _isInputFocused = _inputFocusNode.hasFocus;
      });
    });
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
      _todos.clear();
      _isDarkMode = storedDarkMode;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final TodoItem todo in parsedTodos) {
        final int insertIndex = _todos.length;
        _todos.add(todo);
        _listKey.currentState?.insertItem(
          insertIndex,
          duration: const Duration(milliseconds: 350),
        );
      }
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
    _addButtonController.dispose();
    _inputFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addTask() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    final int insertIndex = _todos.length;
    setState(() {
      _todos.add(TodoItem(title: text));
    });
    _listKey.currentState?.insertItem(
      insertIndex,
      duration: const Duration(milliseconds: 380),
    );
    _controller.clear();
    _inputFocusNode.requestFocus();
    _saveTasks();
  }

  void _toggleTask(int index, bool value) {
    setState(() {
      _todos[index].isDone = value;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    final TodoItem removedItem = _todos[index];
    setState(() {
      _todos.removeAt(index);
    });
    _listKey.currentState?.removeItem(
      index,
      (BuildContext context, Animation<double> animation) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: _buildTaskTile(removedItem, index, kAlwaysDismissedAnimation),
        );
      },
      duration: const Duration(milliseconds: 280),
    );
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

  Color get _effectiveBackgroundColor =>
      _isDarkMode ? _bgColor : const Color(0xFF141414);

  void _clearCompletedTasks() {
    for (int i = _todos.length - 1; i >= 0; i--) {
      if (_todos[i].isDone) {
        _deleteTask(i);
      }
    }
  }

  Future<void> _handleAddTapDown(TapDownDetails _) async {
    await _addButtonController.forward();
  }

  Future<void> _handleAddTapCancel() async {
    await _addButtonController.reverse();
  }

  Future<void> _handleAddTapUp(TapUpDetails _) async {
    await _addButtonController.reverse();
    _addTask();
  }

  Widget _buildTaskTile(
    TodoItem todo,
    int index,
    Animation<double> animation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.16, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: _accentColor.withOpacity(0.85), width: 3),
              ),
            ),
            child: ListTile(
              leading: GestureDetector(
                onTap: index >= 0 ? () => _toggleTask(index, !todo.isDone) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: todo.isDone ? _accentColor : Colors.transparent,
                    border: Border.all(
                      color: _accentColor,
                      width: 2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _accentColor.withOpacity(todo.isDone ? 0.45 : 0.2),
                        blurRadius: todo.isDone ? 11 : 6,
                        spreadRadius: todo.isDone ? 0.7 : 0.2,
                      ),
                    ],
                  ),
                  child: todo.isDone
                      ? const Icon(Icons.check, color: _bgColor, size: 14)
                      : null,
                ),
              ),
              title: Text(
                todo.title,
                style: TextStyle(
                  color: todo.isDone ? _completedTextColor : _activeTextColor,
                  decoration:
                      todo.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: _completedTextColor,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: _accentColor.withOpacity(0.85)),
                onPressed: index >= 0 ? () => _deleteTask(index) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _effectiveBackgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: _accentColor,
          secondary: _accentColor,
          surface: _cardColor,
          onSurface: _activeTextColor,
          onPrimary: _bgColor,
          onSecondary: _bgColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgColor,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _accentColor,
          elevation: 0,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: _accentColor.withOpacity(0.35),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'MISSION LOG',
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              if (_todos.isNotEmpty)
                Text(
                  '$_completedCount of ${_todos.length} done',
                  style: TextStyle(
                    color: _activeTextColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            if (_completedCount > 0)
              TextButton(
                onPressed: _clearCompletedTasks,
                child: const Text(
                  'Clear completed',
                  style: TextStyle(color: _accentColor),
                ),
              ),
            IconButton(
              onPressed: _toggleDarkMode,
              icon: Icon(
                _isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: _accentColor,
              ),
              tooltip: _isDarkMode ? 'Light mode' : 'Dark mode',
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  AnimatedList(
                    key: _listKey,
                    initialItemCount: _todos.length,
                    itemBuilder:
                        (BuildContext context, int index, Animation<double> animation) {
                      final TodoItem todo = _todos[index];
                      return _buildTaskTile(todo, index, animation);
                    },
                  ),
                  if (_todos.isEmpty)
                    Center(
                      child: Text(
                        'No missions yet',
                        style: TextStyle(color: _activeTextColor.withOpacity(0.65)),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isInputFocused
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: _accentColor.withOpacity(0.22),
                                    blurRadius: 14,
                                    spreadRadius: 0.7,
                                  ),
                                ]
                              : const <BoxShadow>[],
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _inputFocusNode,
                          onSubmitted: (_) => _addTask(),
                          style: const TextStyle(color: _activeTextColor),
                          decoration: InputDecoration(
                            hintText: 'ENTER MISSION...',
                            hintStyle: TextStyle(
                              color: _accentColor.withOpacity(0.55),
                              letterSpacing: 1.0,
                            ),
                            filled: true,
                            fillColor: _cardColor,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _accentColor.withOpacity(0.35),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: _accentColor, width: 1.4),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTapDown: _handleAddTapDown,
                      onTapCancel: _handleAddTapCancel,
                      onTapUp: _handleAddTapUp,
                      child: AnimatedBuilder(
                        animation: _addButtonScale,
                        builder: (BuildContext context, Widget? child) {
                          return Transform.scale(
                            scale: _addButtonScale.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _accentColor.withOpacity(0.85),
                                  width: 1.3,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.75),
                                    offset: const Offset(0, 5),
                                    blurRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: _accentColor.withOpacity(0.35),
                                    blurRadius: 14,
                                    spreadRadius: 0.6,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(
                                  color: _accentColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
