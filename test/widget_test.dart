// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_list/main.dart';
import 'package:todo_list/data/todo_repository.dart';
import 'package:todo_list/models/todo.dart';

class InMemoryTodoRepo implements TodoRepositoryBase {
  final List<Todo> _storage = [];
  @override
  Future<void> init() async {}

  @override
  Future<void> addTodo(Todo todo) async {
    _storage.add(todo);
  }

  @override
  Future<void> clearCompleted() async {
    _storage.removeWhere((t) => t.completed);
  }

  @override
  Future<void> deleteTodo(int id) async {
    _storage.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<Todo>> loadTodos() async => List<Todo>.from(_storage);

  @override
  Future<void> updateTodo(Todo todo) async {
    final i = _storage.indexWhere((t) => t.id == todo.id);
    if (i >= 0) _storage[i] = todo;
  }

  @override
  Future<void> saveAll(List<Todo> todos) async {
    _storage
      ..clear()
      ..addAll(todos);
  }
}

void main() {
  testWidgets('Add a todo and see it in the list', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final repo = InMemoryTodoRepo();
    await repo.init();
    await tester.pumpWidget(MaterialApp(home: MyApp(repository: repo)));

    // Verify empty state message.
    expect(find.text('No tasks yet. Tap + to add one.'), findsOneWidget);

    // Tap the '+' icon to add a task.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Enter a task title and save.
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The new task should appear in the list.
    expect(find.text('Buy milk'), findsOneWidget);
  });
}
