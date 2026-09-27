import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ff_constants.dart';
import '../../domain/engine/routine_clock.dart';
import '../../domain/model/template.dart';
import '../db/database.dart';

/// A routine with its blocks already loaded, in order.
class RoutineWithBlocks {
  const RoutineWithBlocks(this.routine, this.blocks);

  final Routine routine;
  final List<Block> blocks;

  int get totalMinutes => blocks.fold(0, (s, b) => s + b.durationMin);

  int get deepWorkMinutes =>
      blocks.where((b) => b.category == 0).fold(0, (s, b) => s + b.durationMin);

  int get trackedCount => blocks.where((b) => b.trackEnabled).length;

  /// Routines may be longer than the device can hold. The app then keeps the
  /// whole routine and gives the bot the next stretch of it at a time.
  bool get fitsDevice => blocks.length <= FfFirmware.maxDeviceBlocks;

  int get overflowCount =>
      (blocks.length - FfFirmware.maxDeviceBlocks).clamp(0, blocks.length);

  /// The first blocks, in order, that would actually reach the device.
  List<Block> get pushable => windowFrom(0);

  /// The blocks the bot should hold while the routine is on block [from].
  List<Block> windowFrom(int from) {
    final w = RoutineClock.deviceWindow(blocks.length, from);
    return blocks.sublist(w.start, w.end);
  }

  /// The blocks as time sees them, for [RoutineClock].
  List<TimedBlock> get timed => <TimedBlock>[
    for (final b in blocks) (startMin: b.startMin, durationMin: b.durationMin),
  ];

  /// True when the routine's blocks are appointments on the wall clock.
  bool get isTimed => RoutineClock.starts(timed) != null;
}

class RoutineRepository {
  RoutineRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  // --- reads -----------------------------------------------------------------

  Stream<List<Routine>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.routines)
      ..orderBy(<OrderClauseGenerator<$RoutinesTable>>[
        (t) => OrderingTerm(expression: t.isBuiltIn, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.name),
      ]);
    if (!includeArchived) {
      q.where((t) => t.archived.equals(false));
    }
    return q.watch();
  }

  Future<RoutineWithBlocks?> load(String routineId) async {
    final routine = await (_db.select(
      _db.routines,
    )..where((t) => t.id.equals(routineId))).getSingleOrNull();
    if (routine == null) return null;
    return RoutineWithBlocks(routine, await _blocksOf(routineId));
  }

  Stream<RoutineWithBlocks?> watch(String routineId) {
    final routineStream = (_db.select(
      _db.routines,
    )..where((t) => t.id.equals(routineId))).watchSingleOrNull();
    return routineStream.asyncMap(
      (r) async =>
          r == null ? null : RoutineWithBlocks(r, await _blocksOf(routineId)),
    );
  }

  Future<List<Block>> _blocksOf(String routineId) =>
      (_db.select(_db.blocks)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy(<OrderClauseGenerator<$BlocksTable>>[
              (t) => OrderingTerm(expression: t.position),
            ]))
          .get();

  // --- writes ----------------------------------------------------------------

  /// Create an empty routine.
  Future<String> create({required String name, String description = ''}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db
        .into(_db.routines)
        .insert(
          RoutinesCompanion.insert(
            id: id,
            name: name,
            description: Value(description),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Save a generated routine as the user's own.
  Future<String> createFrom({
    required String name,
    String description = '',
    required List<TemplateBlock> blocks,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db
          .into(_db.routines)
          .insert(
            RoutinesCompanion.insert(
              id: id,
              name: name,
              description: Value(description),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _insertTemplateBlocks(
        id,
        RoutineTemplate(key: '', name: name, description: '', blocks: blocks),
      );
    });
    return id;
  }

  /// Copy a routine, including its blocks. This is what "Duplicate to edit"
  /// does to a built-in — the shipped template is never mutated, so it can be
  /// re-seeded or corrected in a later version without touching the user's copy.
  Future<String> duplicate(String sourceId, {String? newName}) async {
    final source = await load(sourceId);
    if (source == null) {
      throw StateError('routine $sourceId does not exist');
    }
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db
          .into(_db.routines)
          .insert(
            RoutinesCompanion.insert(
              id: id,
              name: newName ?? _copyName(source.routine.name),
              description: Value(source.routine.description),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _db.batch((b) {
        b.insertAll(_db.blocks, <BlocksCompanion>[
          for (var i = 0; i < source.blocks.length; i++)
            _companionFrom(
              source.blocks[i],
              routineId: id,
              position: i,
              id: _uuid.v4(),
            ),
        ]);
      });
    });
    return id;
  }

  Future<void> rename(String routineId, String name, {String? description}) =>
      (_db.update(_db.routines)..where((t) => t.id.equals(routineId))).write(
        RoutinesCompanion(
          name: Value(name),
          description: description == null
              ? const Value.absent()
              : Value(description),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> archive(String routineId, {bool archived = true}) =>
      (_db.update(_db.routines)..where((t) => t.id.equals(routineId))).write(
        RoutinesCompanion(
          archived: Value(archived),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Built-ins are never deleted, only archived — a shipped template is part of
  /// the app, not the user's data.
  Future<void> delete(String routineId) async {
    final r = await (_db.select(
      _db.routines,
    )..where((t) => t.id.equals(routineId))).getSingleOrNull();
    if (r == null) return;
    if (r.isBuiltIn) {
      await archive(routineId);
      return;
    }
    await (_db.delete(_db.routines)..where((t) => t.id.equals(routineId))).go();
  }

  Future<String> addBlock(
    String routineId, {
    required String name,
    required int durationMin,
    required int category,
    String description = '',
    bool trackEnabled = false,
    int startMin = FfFirmware.sequentialStartMin,
    int? position,
  }) async {
    final id = _uuid.v4();
    final existing = await _blocksOf(routineId);
    final at = position ?? existing.length;
    final anchor = _anchorOf(existing);

    await _db.transaction(() async {
      if (at < existing.length) {
        // Shift everything at or after the insertion point down one.
        for (var i = existing.length - 1; i >= at; i--) {
          await (_db.update(_db.blocks)
                ..where((t) => t.id.equals(existing[i].id)))
              .write(BlocksCompanion(position: Value(i + 1)));
        }
      }
      await _db
          .into(_db.blocks)
          .insert(
            BlocksCompanion.insert(
              id: id,
              routineId: routineId,
              position: at,
              name: _clampName(name),
              description: Value(_clampDesc(description)),
              durationMin: durationMin,
              category: category,
              trackEnabled: Value(trackEnabled),
              startMin: Value(startMin),
            ),
          );
      await _retime(routineId, anchor);
      await _touch(routineId);
    });
    return id;
  }

  /// Edit a block.
  ///
  /// In a timed routine a block's start is not free to set on its own — it is
  /// where the block before it ends. So a new start is honoured the way FW
  /// Mentorship does it: moving the first block moves the whole routine, and
  /// moving any other block stretches or shrinks the one before it. Everything
  /// after is then re-timed from the durations, so the day stays contiguous.
  Future<void> updateBlock(
    String blockId, {
    String? name,
    String? description,
    int? durationMin,
    int? category,
    bool? trackEnabled,
    int? startMin,
  }) async {
    final block = await (_db.select(
      _db.blocks,
    )..where((t) => t.id.equals(blockId))).getSingleOrNull();
    if (block == null) return;
    final siblings = await _blocksOf(block.routineId);
    var anchor = _anchorOf(siblings);

    await _db.transaction(() async {
      var writeStart = startMin;
      if (anchor != null) {
        // Timed routine: the start is derived, so it is never written as-is.
        writeStart = null;
        final starts = RoutineClock.starts(<TimedBlock>[
          for (final b in siblings)
            (startMin: b.startMin, durationMin: b.durationMin),
        ])!;
        final index = siblings.indexWhere((b) => b.id == blockId);
        if (startMin != null &&
            !RoutineClock.isSequential(startMin) &&
            index >= 0) {
          final delta = RoutineClock.deltaMinutes(startMin, starts[index]);
          if (delta != 0 && index == 0) {
            anchor = startMin;
          } else if (delta != 0) {
            final before = siblings[index - 1];
            await (_db.update(
              _db.blocks,
            )..where((t) => t.id.equals(before.id))).write(
              BlocksCompanion(
                durationMin: Value(
                  (before.durationMin + delta).clamp(
                    RoutineClock.minBlockMinutes,
                    RoutineClock.maxBlockMinutes,
                  ),
                ),
              ),
            );
          }
        }
      }

      await (_db.update(_db.blocks)..where((t) => t.id.equals(blockId))).write(
        BlocksCompanion(
          name: name == null ? const Value.absent() : Value(_clampName(name)),
          description: description == null
              ? const Value.absent()
              : Value(_clampDesc(description)),
          durationMin: durationMin == null
              ? const Value.absent()
              : Value(durationMin),
          category: category == null ? const Value.absent() : Value(category),
          trackEnabled: trackEnabled == null
              ? const Value.absent()
              : Value(trackEnabled),
          startMin: writeStart == null
              ? const Value.absent()
              : Value(writeStart),
        ),
      );
      await _retime(block.routineId, anchor);
      await _touch(block.routineId);
    });
  }

  Future<void> deleteBlock(String blockId) async {
    final block = await (_db.select(
      _db.blocks,
    )..where((t) => t.id.equals(blockId))).getSingleOrNull();
    if (block == null) return;

    final anchor = _anchorOf(await _blocksOf(block.routineId));
    await _db.transaction(() async {
      await (_db.delete(_db.blocks)..where((t) => t.id.equals(blockId))).go();
      await _renumber(block.routineId);
      await _retime(block.routineId, anchor);
      await _touch(block.routineId);
    });
  }

  /// Move a block from [from] to [to] within its routine.
  Future<void> reorder(String routineId, int from, int to) async {
    final blocks = await _blocksOf(routineId);
    if (from < 0 || from >= blocks.length) return;
    final clampedTo = to.clamp(0, blocks.length - 1);
    if (from == clampedTo) return;

    final reordered = List<Block>.of(blocks);
    reordered.insert(clampedTo, reordered.removeAt(from));

    await _db.transaction(() async {
      await _db.batch((b) {
        for (var i = 0; i < reordered.length; i++) {
          b.update(
            _db.blocks,
            BlocksCompanion(position: Value(i)),
            where: ($BlocksTable t) => t.id.equals(reordered[i].id),
          );
        }
      });
      await _retime(routineId, _anchorOf(blocks));
      await _touch(routineId);
    });
  }

  // --- seeding ---------------------------------------------------------------

  /// Install the shipped templates.
  ///
  /// Idempotent by `templateKey`: running it on every launch adds templates
  /// introduced in a newer version without touching, duplicating or resurrecting
  /// anything the user already has.
  /// Puts every shipped template back on the list.
  ///
  /// [seedTemplates] alone is not enough and the difference matters: it adds
  /// only templates that are *missing*, so a user who hid all of them has an
  /// empty screen and a button that does nothing — the rows are still there,
  /// just archived. This un-hides what exists and then adds anything new.
  Future<void> restoreTemplates() async {
    await (_db.update(
      _db.routines,
    )..where((t) => t.isBuiltIn.equals(true) & t.archived.equals(true))).write(
      RoutinesCompanion(
        archived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await seedTemplates();
  }

  /// Template key → routine id, for the shipped tracks this phone holds.
  ///
  /// Onboarding needs to point [SettingKey.activeRoutineId] at a real row, and
  /// the row's id is generated at seed time rather than being the key itself.
  Future<Map<String, String>> allTemplates() async {
    final rows = await (_db.select(
      _db.routines,
    )..where((t) => t.templateKey.isNotNull())).get();
    return <String, String>{
      for (final r in rows)
        if (r.templateKey != null) r.templateKey!: r.id,
    };
  }

  /// Brings the shipped templates on this phone in line with this version.
  ///
  /// Idempotent by `templateKey`, and safe on every launch:
  ///
  /// * a template this version adds is installed;
  /// * a built-in whose shipped blocks changed is rewritten — built-ins are
  ///   read-only, so there is no user edit to lose, and without this a phone
  ///   keeps whatever the first version it ran happened to ship;
  /// * a built-in this version no longer ships is removed. Sessions keep their
  ///   own copy of the block name, so history is untouched.
  ///
  /// A user's copies carry no `templateKey` and are never looked at. Hidden
  /// built-ins stay hidden.
  Future<void> seedTemplates() async {
    final existing =
        await (_db.select(_db.routines)..where(
              (t) => t.templateKey.isNotNull() & t.isBuiltIn.equals(true),
            ))
            .get();
    final byKey = <String, Routine>{
      for (final r in existing) r.templateKey!: r,
    };
    final shipped = <String>{for (final t in Templates.all) t.key};

    final now = DateTime.now();
    await _db.transaction(() async {
      for (var i = 0; i < Templates.all.length; i++) {
        final template = Templates.all[i];
        final row = byKey[template.key];
        if (row == null) {
          final routineId = _uuid.v4();
          await _db
              .into(_db.routines)
              .insert(
                RoutinesCompanion.insert(
                  id: routineId,
                  name: template.name,
                  description: Value(template.description),
                  isBuiltIn: const Value(true),
                  templateKey: Value(template.key),
                  sortOrder: Value(i),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await _insertTemplateBlocks(routineId, template);
          continue;
        }

        final blocks = await _blocksOf(row.id);
        final same =
            row.name == template.name &&
            row.description == template.description &&
            row.sortOrder == i &&
            _sameBlocks(blocks, template.blocks);
        if (same) continue;

        await (_db.update(
          _db.routines,
        )..where((t) => t.id.equals(row.id))).write(
          RoutinesCompanion(
            name: Value(template.name),
            description: Value(template.description),
            sortOrder: Value(i),
            updatedAt: Value(now),
          ),
        );
        if (!_sameBlocks(blocks, template.blocks)) {
          await (_db.delete(
            _db.blocks,
          )..where((t) => t.routineId.equals(row.id))).go();
          await _insertTemplateBlocks(row.id, template);
        }
      }

      for (final row in existing) {
        if (shipped.contains(row.templateKey)) continue;
        await (_db.delete(
          _db.blocks,
        )..where((t) => t.routineId.equals(row.id))).go();
        await (_db.delete(
          _db.routines,
        )..where((t) => t.id.equals(row.id))).go();
      }
    });
  }

  Future<void> _insertTemplateBlocks(
    String routineId,
    RoutineTemplate template,
  ) => _db.batch((b) {
    b.insertAll(_db.blocks, <BlocksCompanion>[
      for (var p = 0; p < template.blocks.length; p++)
        BlocksCompanion.insert(
          id: _uuid.v4(),
          routineId: routineId,
          position: p,
          name: template.blocks[p].name,
          description: Value(template.blocks[p].description),
          durationMin: template.blocks[p].durationMin,
          category: template.blocks[p].category,
          trackEnabled: Value(template.blocks[p].track),
          startMin: Value(
            template.blocks[p].startMin ?? FfFirmware.sequentialStartMin,
          ),
        ),
    ]);
  });

  static bool _sameBlocks(List<Block> have, List<TemplateBlock> want) {
    if (have.length != want.length) return false;
    for (var i = 0; i < have.length; i++) {
      final h = have[i];
      final w = want[i];
      if (h.name != w.name ||
          h.description != w.description ||
          h.durationMin != w.durationMin ||
          h.category != w.category ||
          h.trackEnabled != w.track ||
          h.startMin != (w.startMin ?? FfFirmware.sequentialStartMin)) {
        return false;
      }
    }
    return true;
  }

  // --- helpers ---------------------------------------------------------------

  /// The start time of a timed routine, or null for a sequential one.
  ///
  /// Read *before* an edit and passed to [_retime] after it, so the routine
  /// keeps its start even when the edit moves its first block away.
  static int? _anchorOf(List<Block> blocks) {
    if (blocks.isEmpty) return null;
    final first = blocks.first.startMin;
    return RoutineClock.isSequential(first) ? null : first;
  }

  /// Re-derive every block's start from [anchor] and the durations.
  Future<void> _retime(String routineId, int? anchor) async {
    if (anchor == null) return;
    final blocks = await _blocksOf(routineId);
    final times = RoutineClock.retime(<int>[
      for (final b in blocks) b.durationMin,
    ], anchor);
    await _db.batch((b) {
      for (var i = 0; i < blocks.length; i++) {
        if (blocks[i].startMin == times[i]) continue;
        b.update(
          _db.blocks,
          BlocksCompanion(startMin: Value(times[i])),
          where: ($BlocksTable t) => t.id.equals(blocks[i].id),
        );
      }
    });
  }

  Future<void> _renumber(String routineId) async {
    final blocks = await _blocksOf(routineId);
    await _db.batch((b) {
      for (var i = 0; i < blocks.length; i++) {
        if (blocks[i].position == i) continue;
        b.update(
          _db.blocks,
          BlocksCompanion(position: Value(i)),
          where: ($BlocksTable t) => t.id.equals(blocks[i].id),
        );
      }
    });
  }

  Future<void> _touch(String routineId) =>
      (_db.update(_db.routines)..where((t) => t.id.equals(routineId))).write(
        RoutinesCompanion(updatedAt: Value(DateTime.now())),
      );

  BlocksCompanion _companionFrom(
    Block source, {
    required String routineId,
    required int position,
    required String id,
  }) => BlocksCompanion.insert(
    id: id,
    routineId: routineId,
    position: position,
    name: source.name,
    description: Value(source.description),
    durationMin: source.durationMin,
    category: source.category,
    trackEnabled: Value(source.trackEnabled),
    startMin: Value(source.startMin),
  );

  static String _copyName(String name) {
    const suffix = ' copy';
    final max = 60 - suffix.length;
    final base = name.length > max ? name.substring(0, max) : name;
    return '$base$suffix';
  }

  /// The firmware structs are fixed-size, so these are hard limits rather than
  /// suggestions. The editor enforces them at input time; this is the backstop.
  static String _clampName(String v) => v.length <= FfFirmware.blockNameMaxChars
      ? v
      : v.substring(0, FfFirmware.blockNameMaxChars);

  static String _clampDesc(String v) => v.length <= FfFirmware.blockDescMaxChars
      ? v
      : v.substring(0, FfFirmware.blockDescMaxChars);
}
