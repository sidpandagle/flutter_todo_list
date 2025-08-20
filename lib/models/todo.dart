class Todo {
  final int id;
  final String title;
  final bool completed;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Todo copyWith({
    int? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
  }) => Todo(
    id: id ?? this.id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
    createdAt: createdAt ?? this.createdAt,
  );

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as int,
    title: json['title'] as String,
    completed: json['completed'] as bool,
    createdAt: json.containsKey('createdAt')
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };
}
