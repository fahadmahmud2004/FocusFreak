import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ff_format.dart';
import '../db/database.dart';

/// A task with its checklist loaded.
class TaskWithSubtasks {
  const TaskWithSubtasks(this.task, this.subtasks, this.tags);

  final Task task;
  final List<Subtask> subtasks;
  final List<Tag> tags;

  bool get isDone => task.completedAt != null;

  int get doneSubtasks => subtasks.where((s) => s.done).length;

  double get checklistProgress =>
      subtasks.isEmpty ? 0 : doneSubtasks / subtasks.length;

  bool get isOverdue {
    final due = task.dueAt;
    return due != null && !isDone && due.isBefore(DateTime.now());
  }
}

/// How a task list is filtered.
enum TaskFilter { today, upcoming, all, completed, overdue }

class TaskRepository {
  TaskRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  // --- reads -----------------------------------------------------------------

  /// How many tasks have ever been ticked off. For the milestones, which count
  /// the whole record rather than what is currently on the list.
  Future<int> completedCount() async {
    final rows = await (_db.select(
      _db.tasks,
    )..where((t) => t.completedAt.isNotNull())).get();
    return rows.length;
  }

  Stream<List<Task>> watch(TaskFilter filter) {
    final now = DateTime.now();
    final endOfToday = FfDates.startOfDay(now).add(const Duration(days: 1));

    final q = _db.select(_db.tasks);
    switch (filter) {
      case TaskFilter.today:
        q.where(
          (t) =>
              t.completedAt.isNull() &
              (t.dueAt.isNull() | t.dueAt.isSmallerThanValue(endOfToday)),
        );
      case TaskFilter.upcoming:
        q.where(
          (t) =>
              t.completedAt.isNull() & t.dueAt.isBiggerOrEqualValue(endOfToday),
        );
      case TaskFilter.overdue:
        q.where(
          (t) => t.completedAt.isNull() & t.dueAt.isSmallerThanValue(now),
        );
      case TaskFilter.completed:
        q.where((t) => t.completedAt.isNotNull());
      case TaskFilter.all:
        break;
    }

    q.orderBy(<OrderClauseGenerator<$TasksTable>>[
      // Overdue and due-soon first, then by explicit priority, then by the
      // user's own ordering. Undated tasks sort last rather than first — an
      // undated task is not urgent, it is just undated.
      (t) => OrderingTerm(expression: t.dueAt, nulls: NullsOrder.last),
      (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.sortOrder),
      (t) => OrderingTerm(expression: t.createdAt),
    ]);
    return q.watch();
  }

  Future<TaskWithSubtasks?> load(String taskId) async {
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return null;
    return TaskWithSubtasks(
      task,
      await _subtasksOf(taskId),
      await _tagsOf(taskId),
    );
  }

  Stream<TaskWithSubtasks?> watchOne(String taskId) =>
      (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(taskId))).watchSingleOrNull().asyncMap(
        (t) async => t == null
            ? null
            : TaskWithSubtasks(
                t,
                await _subtasksOf(taskId),
                await _tagsOf(taskId),
              ),
      );

  Future<List<Subtask>> _subtasksOf(String taskId) =>
      (_db.select(_db.subtasks)
            ..where((t) => t.taskId.equals(taskId))
            ..orderBy(<OrderClauseGenerator<$SubtasksTable>>[
              (t) => OrderingTerm(expression: t.position),
            ]))
          .get();

  Future<List<Tag>> _tagsOf(String taskId) {
    final query = _db.select(_db.tags).join(<Join>[
      innerJoin(_db.taskTags, _db.taskTags.tagId.equalsExp(_db.tags.id)),
    ])..where(_db.taskTags.taskId.equals(taskId));
    return query.map((row) => row.readTable(_db.tags)).get();
  }

  // --- writes ----------------------------------------------------------------

  Future<String> create({
    required String title,
    String notes = '',
    int priority = 0,
    int? category,
    DateTime? dueAt,
    int estimatedPomodoros = 0,
    String? recurrence,
    String? blockId,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            title: title,
            notes: Value(notes),
            priority: Value(priority),
            category: Value(category),
            dueAt: Value(dueAt),
            createdAt: DateTime.now(),
            estimatedPomodoros: Value(estimatedPomodoros),
            recurrence: Value(recurrence),
            blockId: Value(blockId),
          ),
        );
    return id;
  }

  Future<void> update(
    String taskId, {
    String? title,
    String? notes,
    int? priority,
    int? category,
    DateTime? dueAt,
    bool clearDueAt = false,
    int? estimatedPomodoros,
    String? recurrence,
  }) => (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
    TasksCompanion(
      title: title == null ? const Value.absent() : Value(title),
      notes: notes == null ? const Value.absent() : Value(notes),
      priority: priority == null ? const Value.absent() : Value(priority),
      category: category == null ? const Value.absent() : Value(category),
      dueAt: clearDueAt
          ? const Value<DateTime?>(null)
          : (dueAt == null ? const Value.absent() : Value(dueAt)),
      estimatedPomodoros: estimatedPomodoros == null
          ? const Value.absent()
          : Value(estimatedPomodoros),
      recurrence: recurrence == null ? const Value.absent() : Value(recurrence),
    ),
  );

  /// Toggle completion.
  ///
  /// A recurring task is never really "done": completing it rolls its due date
  /// forward and leaves it open, which is the only behaviour that makes a daily
  /// habit list usable past day one.
  Future<void> setDone(String taskId, bool done, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return;

    if (done && task.recurrence != null && task.dueAt != null) {
      final next = _nextOccurrence(task.dueAt!, task.recurrence!);
      if (next != null) {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
          TasksCompanion(
            dueAt: Value(next),
            completedPomodoros: const Value(0),
          ),
        );
        await (_db.update(_db.subtasks)..where((t) => t.taskId.equals(taskId)))
            .write(const SubtasksCompanion(done: Value(false)));
        return;
      }
    }

    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(completedAt: Value(done ? now : null)),
    );
  }

  Future<void> delete(String taskId) =>
      (_db.delete(_db.tasks)..where((t) => t.id.equals(taskId))).go();

  Future<void> incrementPomodoro(String taskId) async {
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(completedPomodoros: Value(task.completedPomodoros + 1)),
    );
  }

  // --- subtasks ----------------------------------------------------------------

  Future<String> addSubtask(String taskId, String title) async {
    final id = _uuid.v4();
    final existing = await _subtasksOf(taskId);
    await _db
        .into(_db.subtasks)
        .insert(
          SubtasksCompanion.insert(
            id: id,
            taskId: taskId,
            title: title,
            position: existing.length,
          ),
        );
    return id;
  }

  Future<void> setSubtaskDone(String subtaskId, bool done) =>
      (_db.update(_db.subtasks)..where((t) => t.id.equals(subtaskId))).write(
        SubtasksCompanion(done: Value(done)),
      );

  Future<void> deleteSubtask(String subtaskId) =>
      (_db.delete(_db.subtasks)..where((t) => t.id.equals(subtaskId))).go();

  // --- tags ---------------------------------------------------------------------

  Stream<List<Tag>> watchTags() =>
      (_db.select(_db.tags)..orderBy(<OrderClauseGenerator<$TagsTable>>[
            (t) => OrderingTerm(expression: t.name),
          ]))
          .watch();

  Future<String> createTag(String name, {int colorIndex = 0}) async {
    final id = _uuid.v4();
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(
            id: id,
            name: name,
            colorIndex: Value(colorIndex),
          ),
        );
    return id;
  }

  Future<void> attachTag(String taskId, String tagId) => _db
      .into(_db.taskTags)
      .insertOnConflictUpdate(
        TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
      );

  Future<void> detachTag(String taskId, String tagId) => (_db.delete(
    _db.taskTags,
  )..where((t) => t.taskId.equals(taskId) & t.tagId.equals(tagId))).go();

  /// Recurrence rules, kept deliberately small.
  ///
  /// A full RFC 5545 implementation is a library, not a feature of a focus app.
  /// These five cover what a study routine actually needs.
  static DateTime? _nextOccurrence(DateTime from, String rule) {
    switch (rule) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekdays':
        var next = from.add(const Duration(days: 1));
        while (next.weekday == DateTime.saturday ||
            next.weekday == DateTime.sunday) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'fortnightly':
        return from.add(const Duration(days: 14));
      case 'monthly':
        // Clamped so 31 January + 1 month lands on 28/29 February rather than
        // silently rolling into March.
        final month = from.month == 12 ? 1 : from.month + 1;
        final year = from.month == 12 ? from.year + 1 : from.year;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(
          year,
          month,
          from.day > lastDay ? lastDay : from.day,
          from.hour,
          from.minute,
        );
      default:
        return null;
    }
  }
}
