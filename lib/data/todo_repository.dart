import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo.dart';

/// Minimal repository interface so tests can provide fakes.
abstract class TodoRepositoryBase {
  Future<void> init();
  Future<List<Todo>> loadTodos();
  Future<void> addTodo(Todo todo);
  Future<void> updateTodo(Todo todo);
  Future<void> deleteTodo(int id);
  Future<void> clearCompleted();
  Future<void> saveAll(List<Todo> todos);
}

class SharedPrefsTodoRepository implements TodoRepositoryBase {
  static const _key = 'todos_v1';
  late SharedPreferences _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<List<Todo>> loadTodos() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Todo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> addTodo(Todo todo) async {
    final todos = await loadTodos();
    todos.add(todo);
    await saveTodos(todos);
  }

  @override
  Future<void> updateTodo(Todo todo) async {
    final todos = await loadTodos();
    final idx = todos.indexWhere((t) => t.id == todo.id);
    if (idx >= 0) {
      todos[idx] = todo;
      await saveTodos(todos);
    }
  }

  @override
  Future<void> deleteTodo(int id) async {
    final todos = await loadTodos();
    todos.removeWhere((t) => t.id == id);
    await saveTodos(todos);
  }

  @override
  Future<void> clearCompleted() async {
    final todos = await loadTodos();
    todos.removeWhere((t) => t.completed);
    await saveTodos(todos);
  }

  @override
  Future<void> saveAll(List<Todo> todos) async => saveTodos(todos);

  Future<void> saveTodos(List<Todo> todos) async {
    final raw = jsonEncode(todos.map((t) => t.toJson()).toList());
    await _prefs.setString(_key, raw);
  }
}
