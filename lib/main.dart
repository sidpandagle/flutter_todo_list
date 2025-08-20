import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'models/todo.dart';
import 'data/todo_repository.dart';
import 'package:flutter/services.dart';

const _themeKey = 'selected_theme';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SharedPrefsTodoRepository();
  await repository.init();
  // Seed with sample earlier-dated todos if repo is empty so "Last Activity" shows entries
  final existing = await repository.loadTodos();
  if (existing.isEmpty) {
    final now = DateTime.now();
    final sample1 = Todo(
      id: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      title: 'Review meeting notes',
      completed: false,
      createdAt: now.subtract(const Duration(days: 1)),
    );
    final sample2 = Todo(
      id: now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
      title: 'Fix bug #42',
      completed: true,
      createdAt: now.subtract(const Duration(days: 3)),
    );
    await repository.addTodo(sample1);
    await repository.addTodo(sample2);
  }
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_themeKey);
  runApp(MyApp(repository: repository, savedThemeKey: saved));
}

class MyApp extends StatefulWidget {
  final TodoRepositoryBase repository;
  final String? savedThemeKey;
  const MyApp({super.key, required this.repository, this.savedThemeKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    if (widget.savedThemeKey != null) {
      final key = widget.savedThemeKey!;
      if (key == 'system') _themeMode = ThemeMode.system;
      if (key == 'light') _themeMode = ThemeMode.light;
      if (key == 'dark') _themeMode = ThemeMode.dark;
    }
  }

  Future<void> _saveTheme(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, key);
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveTheme(
      mode == ThemeMode.system
          ? 'system'
          : mode == ThemeMode.light
          ? 'light'
          : 'dark',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List',
      themeMode: _themeMode,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: TodoHome(
        repository: widget.repository,
        onOpenTheme: (BuildContext ctx) async {
          // show theme picker using the TodoHome's context so MaterialLocalizations are available
          await showDialog<void>(
            context: ctx,
            builder: (c) => SimpleDialog(
              title: const Text('Theme'),
              children: [
                SimpleDialogOption(
                  child: const Text('Follow system'),
                  onPressed: () {
                    _setThemeMode(ThemeMode.system);
                    Navigator.pop(c);
                  },
                ),
                SimpleDialogOption(
                  child: const Text('Light'),
                  onPressed: () {
                    _setThemeMode(ThemeMode.light);
                    Navigator.pop(c);
                  },
                ),
                SimpleDialogOption(
                  child: const Text('Dark'),
                  onPressed: () {
                    _setThemeMode(ThemeMode.dark);
                    Navigator.pop(c);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TodoHome extends StatefulWidget {
  final TodoRepositoryBase repository;
  final void Function(BuildContext)? onOpenTheme;
  const TodoHome({super.key, required this.repository, this.onOpenTheme});

  @override
  State<TodoHome> createState() => _TodoHomeState();
}

class _TodoHomeState extends State<TodoHome> {
  List<Todo> _todos = [];
  static const _settingsChannel = MethodChannel('app.settings');

  @override
  void initState() {
    super.initState();
    _load();
    // initialize notifications after widget binding
    NotificationService().init();
  }

  Future<void> _load() async {
    _todos = await widget.repository.loadTodos();
    setState(() {});
  }

  Future<void> _addOrEdit([Todo? existing]) async {
    final controller = TextEditingController(text: existing?.title ?? '');
    final isNew = existing == null;

    final result = await showDialog<Todo?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNew ? 'Add Task' : 'Edit Task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(
                context,
                Todo(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
                  title: text,
                  completed: existing?.completed ?? false,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      if (isNew) {
        await widget.repository.addTodo(result);
      } else {
        await widget.repository.updateTodo(result);
      }
      await _load();
    }
  }

  Future<void> _toggle(Todo todo) async {
    final updated = todo.copyWith(completed: !todo.completed);
    await widget.repository.updateTodo(updated);
    // If the task was just marked completed, ensure permission and show a local notification
    if (!todo.completed && updated.completed) {
      // Check permission via platform channel
      try {
        final Map status =
            (await _settingsChannel.invokeMethod('checkNotificationPermission'))
                as Map;
        if (!mounted) return;
        final granted = status['granted'] as bool? ?? true;
        final shouldShowRationale =
            status['shouldShowRationale'] as bool? ?? false;

        if (!granted) {
          // If system will not show rationale (permanent denial), show our dialog with open settings
          if (!shouldShowRationale) {
            final open = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Enable notifications'),
                content: const Text(
                  'We use notifications to let you know when tasks are completed. Please enable notifications in app settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Open settings'),
                  ),
                ],
              ),
            );

            if (open == true) {
              try {
                await _settingsChannel.invokeMethod('openSettings');
              } on PlatformException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not open settings: ${e.message}'),
                  ),
                );
              }
              // still try to show notification locally if possible
              NotificationService().showTaskCompleted(title: updated.title);
            }
          } else {
            // We can still request permission via the platform channel
            await _settingsChannel.invokeMethod(
              'requestNotificationPermission',
            );
            // After requesting, attempt to show notification (if granted)
            final Map newStatus =
                (await _settingsChannel.invokeMethod(
                      'checkNotificationPermission',
                    ))
                    as Map;
            final newGranted = newStatus['granted'] as bool? ?? true;
            if (newGranted)
              NotificationService().showTaskCompleted(title: updated.title);
          }
        } else {
          NotificationService().showTaskCompleted(title: updated.title);
        }
      } on PlatformException {
        // Fallback: show notification anyway
        NotificationService().showTaskCompleted(title: updated.title);
      }
    }
    await _load();
  }

  Future<bool> _delete(Todo todo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.repository.deleteTodo(todo.id);
      await _load();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final todos = _todos;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('To-Do List'),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Today's Tasks"),
              Tab(text: 'Last Activity'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.color_lens),
              tooltip: 'Theme',
              onPressed: widget.onOpenTheme == null
                  ? null
                  : () => widget.onOpenTheme!(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Clear completed',
              onPressed: () async {
                await widget.repository.clearCompleted();
                await _load();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Today's Tasks (created today)
            Builder(
              builder: (context) {
                final today = DateTime.now();
                final todays = todos.where((t) {
                  final c = t.createdAt;
                  return c.year == today.year &&
                      c.month == today.month &&
                      c.day == today.day;
                }).toList();
                if (todays.isEmpty) {
                  return const Center(child: Text('No tasks for today.'));
                }
                return _buildReorderableList(todays);
              },
            ),
            // Last Activity (not today)
            Builder(
              builder: (context) {
                final today = DateTime.now();
                final others = todos.where((t) {
                  final c = t.createdAt;
                  return !(c.year == today.year &&
                      c.month == today.month &&
                      c.day == today.day);
                }).toList();
                if (others.isEmpty) {
                  return const Center(child: Text('No recent activity.'));
                }
                return _buildReorderableList(others);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addOrEdit(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildReorderableList(List<Todo> list) {
    return ReorderableListView.builder(
      itemCount: list.length,
      onReorder: (oldIndex, newIndex) async {
        // Reordering here operates on the global _todos list: map indices back
        // Find indexes in the master list and reorder accordingly
        final todo = list.removeAt(oldIndex);
        list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, todo);
        // Update the master list to match new ordering
        _todos = [for (var t in _todos) t];
        // Simple approach: replace ordering for items present in 'list'
        final remaining = _todos
            .where((t) => !list.any((lt) => lt.id == t.id))
            .toList();
        _todos = [];
        // Put today's/others (list) first, then remaining
        _todos.addAll(list);
        _todos.addAll(remaining);
        await widget.repository.saveAll(_todos);
        setState(() {});
      },
      buildDefaultDragHandles: false,
      itemBuilder: (context, i) {
        final t = list[i];
        return Dismissible(
          key: ValueKey(t.id),
          movementDuration: const Duration(milliseconds: 200),
          background: Container(
            color: Colors.green,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            child: const Icon(Icons.check, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await _toggle(t);
              return false;
            } else if (direction == DismissDirection.endToStart) {
              final deleted = await _delete(t);
              return deleted;
            }
            return false;
          },
          child: ListTile(
            key: ValueKey('tile-${t.id}'),
            leading: ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle),
            ),
            title: Text(
              t.title,
              style: t.completed
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    )
                  : null,
            ),
            onTap: () => _toggle(t),
            trailing: IconButton(
              icon: Icon(
                t.completed ? Icons.check_circle : Icons.check_circle_outline,
                color: t.completed ? Colors.green : null,
              ),
              onPressed: () => _toggle(t),
            ),
          ),
        );
      },
    );
  }
}
