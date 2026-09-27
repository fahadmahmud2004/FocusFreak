// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RoutinesTable extends Routines with TableInfo<$RoutinesTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _templateKeyMeta = const VerificationMeta(
    'templateKey',
  );
  @override
  late final GeneratedColumn<String> templateKey = GeneratedColumn<String>(
    'template_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    isBuiltIn,
    templateKey,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<Routine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('template_key')) {
      context.handle(
        _templateKeyMeta,
        templateKey.isAcceptableOrUnknown(
          data['template_key']!,
          _templateKeyMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      templateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_key'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final String id;
  final String name;
  final String description;

  /// True for the shipped templates. The editor refuses to mutate these.
  final bool isBuiltIn;

  /// Stable key for a built-in (`standard`, `earlyBird`, `nightOwl`, …), so a
  /// template can be re-seeded or upgraded without duplicating the user's copy.
  final String? templateKey;
  final int sortOrder;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Routine({
    required this.id,
    required this.name,
    required this.description,
    required this.isBuiltIn,
    this.templateKey,
    required this.sortOrder,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    if (!nullToAbsent || templateKey != null) {
      map['template_key'] = Variable<String>(templateKey);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      isBuiltIn: Value(isBuiltIn),
      templateKey: templateKey == null && nullToAbsent
          ? const Value.absent()
          : Value(templateKey),
      sortOrder: Value(sortOrder),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Routine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      templateKey: serializer.fromJson<String?>(json['templateKey']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'templateKey': serializer.toJson<String?>(templateKey),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Routine copyWith({
    String? id,
    String? name,
    String? description,
    bool? isBuiltIn,
    Value<String?> templateKey = const Value.absent(),
    int? sortOrder,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    templateKey: templateKey.present ? templateKey.value : this.templateKey,
    sortOrder: sortOrder ?? this.sortOrder,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      templateKey: data.templateKey.present
          ? data.templateKey.value
          : this.templateKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('templateKey: $templateKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    isBuiltIn,
    templateKey,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.isBuiltIn == this.isBuiltIn &&
          other.templateKey == this.templateKey &&
          other.sortOrder == this.sortOrder &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<bool> isBuiltIn;
  final Value<String?> templateKey;
  final Value<int> sortOrder;
  final Value<bool> archived;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.templateKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutinesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.templateKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archived = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Routine> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isBuiltIn,
    Expression<String>? templateKey,
    Expression<int>? sortOrder,
    Expression<bool>? archived,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (templateKey != null) 'template_key': templateKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutinesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<bool>? isBuiltIn,
    Value<String?>? templateKey,
    Value<int>? sortOrder,
    Value<bool>? archived,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      templateKey: templateKey ?? this.templateKey,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (templateKey.present) {
      map['template_key'] = Variable<String>(templateKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('templateKey: $templateKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlocksTable extends Blocks with TableInfo<$BlocksTable, Block> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 24),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<int> category = GeneratedColumn<int>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackEnabledMeta = const VerificationMeta(
    'trackEnabled',
  );
  @override
  late final GeneratedColumn<bool> trackEnabled = GeneratedColumn<bool>(
    'track_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _startMinMeta = const VerificationMeta(
    'startMin',
  );
  @override
  late final GeneratedColumn<int> startMin = GeneratedColumn<int>(
    'start_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFFFF),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    position,
    name,
    description,
    durationMin,
    category,
    trackEnabled,
    startMin,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Block> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationMinMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('track_enabled')) {
      context.handle(
        _trackEnabledMeta,
        trackEnabled.isAcceptableOrUnknown(
          data['track_enabled']!,
          _trackEnabledMeta,
        ),
      );
    }
    if (data.containsKey('start_min')) {
      context.handle(
        _startMinMeta,
        startMin.isAcceptableOrUnknown(data['start_min']!, _startMinMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Block map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Block(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category'],
      )!,
      trackEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_enabled'],
      )!,
      startMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_min'],
      )!,
    );
  }

  @override
  $BlocksTable createAlias(String alias) {
    return $BlocksTable(attachedDatabase, alias);
  }
}

class Block extends DataClass implements Insertable<Block> {
  final String id;
  final String routineId;
  final int position;

  /// `char name[16]` on the wire.
  final String name;

  /// `char desc[24]` on the wire.
  final String description;
  final int durationMin;

  /// 0..5 — the index is the wire value and the colour index.
  final int category;

  /// Per-block opt-in. Always-on tracking makes the device a tyrant; opt-in
  /// makes it a tool.
  final bool trackEnabled;

  /// Minutes since midnight, or 0xFFFF for "run after the previous block".
  final int startMin;
  const Block({
    required this.id,
    required this.routineId,
    required this.position,
    required this.name,
    required this.description,
    required this.durationMin,
    required this.category,
    required this.trackEnabled,
    required this.startMin,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_id'] = Variable<String>(routineId);
    map['position'] = Variable<int>(position);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['duration_min'] = Variable<int>(durationMin);
    map['category'] = Variable<int>(category);
    map['track_enabled'] = Variable<bool>(trackEnabled);
    map['start_min'] = Variable<int>(startMin);
    return map;
  }

  BlocksCompanion toCompanion(bool nullToAbsent) {
    return BlocksCompanion(
      id: Value(id),
      routineId: Value(routineId),
      position: Value(position),
      name: Value(name),
      description: Value(description),
      durationMin: Value(durationMin),
      category: Value(category),
      trackEnabled: Value(trackEnabled),
      startMin: Value(startMin),
    );
  }

  factory Block.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Block(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String>(json['routineId']),
      position: serializer.fromJson<int>(json['position']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      durationMin: serializer.fromJson<int>(json['durationMin']),
      category: serializer.fromJson<int>(json['category']),
      trackEnabled: serializer.fromJson<bool>(json['trackEnabled']),
      startMin: serializer.fromJson<int>(json['startMin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String>(routineId),
      'position': serializer.toJson<int>(position),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'durationMin': serializer.toJson<int>(durationMin),
      'category': serializer.toJson<int>(category),
      'trackEnabled': serializer.toJson<bool>(trackEnabled),
      'startMin': serializer.toJson<int>(startMin),
    };
  }

  Block copyWith({
    String? id,
    String? routineId,
    int? position,
    String? name,
    String? description,
    int? durationMin,
    int? category,
    bool? trackEnabled,
    int? startMin,
  }) => Block(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    position: position ?? this.position,
    name: name ?? this.name,
    description: description ?? this.description,
    durationMin: durationMin ?? this.durationMin,
    category: category ?? this.category,
    trackEnabled: trackEnabled ?? this.trackEnabled,
    startMin: startMin ?? this.startMin,
  );
  Block copyWithCompanion(BlocksCompanion data) {
    return Block(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      position: data.position.present ? data.position.value : this.position,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      category: data.category.present ? data.category.value : this.category,
      trackEnabled: data.trackEnabled.present
          ? data.trackEnabled.value
          : this.trackEnabled,
      startMin: data.startMin.present ? data.startMin.value : this.startMin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Block(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('durationMin: $durationMin, ')
          ..write('category: $category, ')
          ..write('trackEnabled: $trackEnabled, ')
          ..write('startMin: $startMin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    position,
    name,
    description,
    durationMin,
    category,
    trackEnabled,
    startMin,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Block &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.position == this.position &&
          other.name == this.name &&
          other.description == this.description &&
          other.durationMin == this.durationMin &&
          other.category == this.category &&
          other.trackEnabled == this.trackEnabled &&
          other.startMin == this.startMin);
}

class BlocksCompanion extends UpdateCompanion<Block> {
  final Value<String> id;
  final Value<String> routineId;
  final Value<int> position;
  final Value<String> name;
  final Value<String> description;
  final Value<int> durationMin;
  final Value<int> category;
  final Value<bool> trackEnabled;
  final Value<int> startMin;
  final Value<int> rowid;
  const BlocksCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.position = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.category = const Value.absent(),
    this.trackEnabled = const Value.absent(),
    this.startMin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlocksCompanion.insert({
    required String id,
    required String routineId,
    required int position,
    required String name,
    this.description = const Value.absent(),
    required int durationMin,
    required int category,
    this.trackEnabled = const Value.absent(),
    this.startMin = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routineId = Value(routineId),
       position = Value(position),
       name = Value(name),
       durationMin = Value(durationMin),
       category = Value(category);
  static Insertable<Block> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<int>? position,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? durationMin,
    Expression<int>? category,
    Expression<bool>? trackEnabled,
    Expression<int>? startMin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (position != null) 'position': position,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (durationMin != null) 'duration_min': durationMin,
      if (category != null) 'category': category,
      if (trackEnabled != null) 'track_enabled': trackEnabled,
      if (startMin != null) 'start_min': startMin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? routineId,
    Value<int>? position,
    Value<String>? name,
    Value<String>? description,
    Value<int>? durationMin,
    Value<int>? category,
    Value<bool>? trackEnabled,
    Value<int>? startMin,
    Value<int>? rowid,
  }) {
    return BlocksCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      position: position ?? this.position,
      name: name ?? this.name,
      description: description ?? this.description,
      durationMin: durationMin ?? this.durationMin,
      category: category ?? this.category,
      trackEnabled: trackEnabled ?? this.trackEnabled,
      startMin: startMin ?? this.startMin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(category.value);
    }
    if (trackEnabled.present) {
      map['track_enabled'] = Variable<bool>(trackEnabled.value);
    }
    if (startMin.present) {
      map['start_min'] = Variable<int>(startMin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlocksCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('durationMin: $durationMin, ')
          ..write('category: $category, ')
          ..write('trackEnabled: $trackEnabled, ')
          ..write('startMin: $startMin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<int> category = GeneratedColumn<int>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimatedPomodorosMeta =
      const VerificationMeta('estimatedPomodoros');
  @override
  late final GeneratedColumn<int> estimatedPomodoros = GeneratedColumn<int>(
    'estimated_pomodoros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedPomodorosMeta =
      const VerificationMeta('completedPomodoros');
  @override
  late final GeneratedColumn<int> completedPomodoros = GeneratedColumn<int>(
    'completed_pomodoros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    priority,
    category,
    dueAt,
    completedAt,
    createdAt,
    estimatedPomodoros,
    completedPomodoros,
    recurrence,
    blockId,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('estimated_pomodoros')) {
      context.handle(
        _estimatedPomodorosMeta,
        estimatedPomodoros.isAcceptableOrUnknown(
          data['estimated_pomodoros']!,
          _estimatedPomodorosMeta,
        ),
      );
    }
    if (data.containsKey('completed_pomodoros')) {
      context.handle(
        _completedPomodorosMeta,
        completedPomodoros.isAcceptableOrUnknown(
          data['completed_pomodoros']!,
          _completedPomodorosMeta,
        ),
      );
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      estimatedPomodoros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_pomodoros'],
      )!,
      completedPomodoros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_pomodoros'],
      )!,
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      ),
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String title;
  final String notes;

  /// 0 none · 1 low · 2 medium · 3 high
  final int priority;
  final int? category;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final int estimatedPomodoros;
  final int completedPomodoros;

  /// iCal-ish recurrence string, or null for a one-off.
  final String? recurrence;

  /// Optional link to the block this task is meant to be done in.
  final String? blockId;
  final int sortOrder;
  const Task({
    required this.id,
    required this.title,
    required this.notes,
    required this.priority,
    this.category,
    this.dueAt,
    this.completedAt,
    required this.createdAt,
    required this.estimatedPomodoros,
    required this.completedPomodoros,
    this.recurrence,
    this.blockId,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<int>(category);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['estimated_pomodoros'] = Variable<int>(estimatedPomodoros);
    map['completed_pomodoros'] = Variable<int>(completedPomodoros);
    if (!nullToAbsent || recurrence != null) {
      map['recurrence'] = Variable<String>(recurrence);
    }
    if (!nullToAbsent || blockId != null) {
      map['block_id'] = Variable<String>(blockId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      notes: Value(notes),
      priority: Value(priority),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
      estimatedPomodoros: Value(estimatedPomodoros),
      completedPomodoros: Value(completedPomodoros),
      recurrence: recurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrence),
      blockId: blockId == null && nullToAbsent
          ? const Value.absent()
          : Value(blockId),
      sortOrder: Value(sortOrder),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      priority: serializer.fromJson<int>(json['priority']),
      category: serializer.fromJson<int?>(json['category']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      estimatedPomodoros: serializer.fromJson<int>(json['estimatedPomodoros']),
      completedPomodoros: serializer.fromJson<int>(json['completedPomodoros']),
      recurrence: serializer.fromJson<String?>(json['recurrence']),
      blockId: serializer.fromJson<String?>(json['blockId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'priority': serializer.toJson<int>(priority),
      'category': serializer.toJson<int?>(category),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'estimatedPomodoros': serializer.toJson<int>(estimatedPomodoros),
      'completedPomodoros': serializer.toJson<int>(completedPomodoros),
      'recurrence': serializer.toJson<String?>(recurrence),
      'blockId': serializer.toJson<String?>(blockId),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? notes,
    int? priority,
    Value<int?> category = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    DateTime? createdAt,
    int? estimatedPomodoros,
    int? completedPomodoros,
    Value<String?> recurrence = const Value.absent(),
    Value<String?> blockId = const Value.absent(),
    int? sortOrder,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    priority: priority ?? this.priority,
    category: category.present ? category.value : this.category,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdAt: createdAt ?? this.createdAt,
    estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
    completedPomodoros: completedPomodoros ?? this.completedPomodoros,
    recurrence: recurrence.present ? recurrence.value : this.recurrence,
    blockId: blockId.present ? blockId.value : this.blockId,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      priority: data.priority.present ? data.priority.value : this.priority,
      category: data.category.present ? data.category.value : this.category,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      estimatedPomodoros: data.estimatedPomodoros.present
          ? data.estimatedPomodoros.value
          : this.estimatedPomodoros,
      completedPomodoros: data.completedPomodoros.present
          ? data.completedPomodoros.value
          : this.completedPomodoros,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('priority: $priority, ')
          ..write('category: $category, ')
          ..write('dueAt: $dueAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('estimatedPomodoros: $estimatedPomodoros, ')
          ..write('completedPomodoros: $completedPomodoros, ')
          ..write('recurrence: $recurrence, ')
          ..write('blockId: $blockId, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    priority,
    category,
    dueAt,
    completedAt,
    createdAt,
    estimatedPomodoros,
    completedPomodoros,
    recurrence,
    blockId,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.priority == this.priority &&
          other.category == this.category &&
          other.dueAt == this.dueAt &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt &&
          other.estimatedPomodoros == this.estimatedPomodoros &&
          other.completedPomodoros == this.completedPomodoros &&
          other.recurrence == this.recurrence &&
          other.blockId == this.blockId &&
          other.sortOrder == this.sortOrder);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> notes;
  final Value<int> priority;
  final Value<int?> category;
  final Value<DateTime?> dueAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime> createdAt;
  final Value<int> estimatedPomodoros;
  final Value<int> completedPomodoros;
  final Value<String?> recurrence;
  final Value<String?> blockId;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.priority = const Value.absent(),
    this.category = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.estimatedPomodoros = const Value.absent(),
    this.completedPomodoros = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.blockId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String title,
    this.notes = const Value.absent(),
    this.priority = const Value.absent(),
    this.category = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    required DateTime createdAt,
    this.estimatedPomodoros = const Value.absent(),
    this.completedPomodoros = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.blockId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? priority,
    Expression<int>? category,
    Expression<DateTime>? dueAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? estimatedPomodoros,
    Expression<int>? completedPomodoros,
    Expression<String>? recurrence,
    Expression<String>? blockId,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (priority != null) 'priority': priority,
      if (category != null) 'category': category,
      if (dueAt != null) 'due_at': dueAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (estimatedPomodoros != null) 'estimated_pomodoros': estimatedPomodoros,
      if (completedPomodoros != null) 'completed_pomodoros': completedPomodoros,
      if (recurrence != null) 'recurrence': recurrence,
      if (blockId != null) 'block_id': blockId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? notes,
    Value<int>? priority,
    Value<int?>? category,
    Value<DateTime?>? dueAt,
    Value<DateTime?>? completedAt,
    Value<DateTime>? createdAt,
    Value<int>? estimatedPomodoros,
    Value<int>? completedPomodoros,
    Value<String?>? recurrence,
    Value<String?>? blockId,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueAt: dueAt ?? this.dueAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      recurrence: recurrence ?? this.recurrence,
      blockId: blockId ?? this.blockId,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(category.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (estimatedPomodoros.present) {
      map['estimated_pomodoros'] = Variable<int>(estimatedPomodoros.value);
    }
    if (completedPomodoros.present) {
      map['completed_pomodoros'] = Variable<int>(completedPomodoros.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('priority: $priority, ')
          ..write('category: $category, ')
          ..write('dueAt: $dueAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('estimatedPomodoros: $estimatedPomodoros, ')
          ..write('completedPomodoros: $completedPomodoros, ')
          ..write('recurrence: $recurrence, ')
          ..write('blockId: $blockId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtasksTable extends Subtasks with TableInfo<$SubtasksTable, Subtask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, taskId, title, done, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subtask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subtask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subtask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SubtasksTable createAlias(String alias) {
    return $SubtasksTable(attachedDatabase, alias);
  }
}

class Subtask extends DataClass implements Insertable<Subtask> {
  final String id;
  final String taskId;
  final String title;
  final bool done;
  final int position;
  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.done,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['title'] = Variable<String>(title);
    map['done'] = Variable<bool>(done);
    map['position'] = Variable<int>(position);
    return map;
  }

  SubtasksCompanion toCompanion(bool nullToAbsent) {
    return SubtasksCompanion(
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      done: Value(done),
      position: Value(position),
    );
  }

  factory Subtask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subtask(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      done: serializer.fromJson<bool>(json['done']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'title': serializer.toJson<String>(title),
      'done': serializer.toJson<bool>(done),
      'position': serializer.toJson<int>(position),
    };
  }

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    bool? done,
    int? position,
  }) => Subtask(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    done: done ?? this.done,
    position: position ?? this.position,
  );
  Subtask copyWithCompanion(SubtasksCompanion data) {
    return Subtask(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      done: data.done.present ? data.done.value : this.done,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subtask(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, title, done, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subtask &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.done == this.done &&
          other.position == this.position);
}

class SubtasksCompanion extends UpdateCompanion<Subtask> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> title;
  final Value<bool> done;
  final Value<int> position;
  final Value<int> rowid;
  const SubtasksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.done = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtasksCompanion.insert({
    required String id,
    required String taskId,
    required String title,
    this.done = const Value.absent(),
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       title = Value(title),
       position = Value(position);
  static Insertable<Subtask> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? title,
    Expression<bool>? done,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (done != null) 'done': done,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtasksCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? title,
    Value<bool>? done,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SubtasksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      done: done ?? this.done,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtasksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('done: $done, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final int colorIndex;
  const Tag({required this.id, required this.name, required this.colorIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      colorIndex: Value(colorIndex),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
    };
  }

  Tag copyWith({String? id, String? name, int? colorIndex}) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.colorIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskTagsTable extends TaskTags with TableInfo<$TaskTagsTable, TaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, tagId};
  @override
  TaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTag(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TaskTagsTable createAlias(String alias) {
    return $TaskTagsTable(attachedDatabase, alias);
  }
}

class TaskTag extends DataClass implements Insertable<TaskTag> {
  final String taskId;
  final String tagId;
  const TaskTag({required this.taskId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TaskTagsCompanion(taskId: Value(taskId), tagId: Value(tagId));
  }

  factory TaskTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTag(
      taskId: serializer.fromJson<String>(json['taskId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TaskTag copyWith({String? taskId, String? tagId}) =>
      TaskTag(taskId: taskId ?? this.taskId, tagId: tagId ?? this.tagId);
  TaskTag copyWithCompanion(TaskTagsCompanion data) {
    return TaskTag(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTag(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTag &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId);
}

class TaskTagsCompanion extends UpdateCompanion<TaskTag> {
  final Value<String> taskId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TaskTagsCompanion({
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTagsCompanion.insert({
    required String taskId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       tagId = Value(tagId);
  static Insertable<TaskTag> custom({
    Expression<String>? taskId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTagsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TaskTagsCompanion(
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logicalDayMeta = const VerificationMeta(
    'logicalDay',
  );
  @override
  late final GeneratedColumn<DateTime> logicalDay = GeneratedColumn<DateTime>(
    'logical_day',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockNameMeta = const VerificationMeta(
    'blockName',
  );
  @override
  late final GeneratedColumn<String> blockName = GeneratedColumn<String>(
    'block_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<int> category = GeneratedColumn<int>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannedSecMeta = const VerificationMeta(
    'plannedSec',
  );
  @override
  late final GeneratedColumn<int> plannedSec = GeneratedColumn<int>(
    'planned_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimedSecMeta = const VerificationMeta(
    'claimedSec',
  );
  @override
  late final GeneratedColumn<int> claimedSec = GeneratedColumn<int>(
    'claimed_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _verifiedSecMeta = const VerificationMeta(
    'verifiedSec',
  );
  @override
  late final GeneratedColumn<int> verifiedSec = GeneratedColumn<int>(
    'verified_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _finalStateMeta = const VerificationMeta(
    'finalState',
  );
  @override
  late final GeneratedColumn<int> finalState = GeneratedColumn<int>(
    'final_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _provenanceMeta = const VerificationMeta(
    'provenance',
  );
  @override
  late final GeneratedColumn<int> provenance = GeneratedColumn<int>(
    'provenance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _factorMaskMeta = const VerificationMeta(
    'factorMask',
  );
  @override
  late final GeneratedColumn<int> factorMask = GeneratedColumn<int>(
    'factor_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _trackEnabledMeta = const VerificationMeta(
    'trackEnabled',
  );
  @override
  late final GeneratedColumn<bool> trackEnabled = GeneratedColumn<bool>(
    'track_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _violationsMeta = const VerificationMeta(
    'violations',
  );
  @override
  late final GeneratedColumn<int> violations = GeneratedColumn<int>(
    'violations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    logicalDay,
    routineId,
    blockId,
    taskId,
    blockName,
    category,
    plannedSec,
    claimedSec,
    verifiedSec,
    finalState,
    provenance,
    factorMask,
    trackEnabled,
    violations,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('logical_day')) {
      context.handle(
        _logicalDayMeta,
        logicalDay.isAcceptableOrUnknown(data['logical_day']!, _logicalDayMeta),
      );
    } else if (isInserting) {
      context.missing(_logicalDayMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('block_name')) {
      context.handle(
        _blockNameMeta,
        blockName.isAcceptableOrUnknown(data['block_name']!, _blockNameMeta),
      );
    } else if (isInserting) {
      context.missing(_blockNameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('planned_sec')) {
      context.handle(
        _plannedSecMeta,
        plannedSec.isAcceptableOrUnknown(data['planned_sec']!, _plannedSecMeta),
      );
    } else if (isInserting) {
      context.missing(_plannedSecMeta);
    }
    if (data.containsKey('claimed_sec')) {
      context.handle(
        _claimedSecMeta,
        claimedSec.isAcceptableOrUnknown(data['claimed_sec']!, _claimedSecMeta),
      );
    }
    if (data.containsKey('verified_sec')) {
      context.handle(
        _verifiedSecMeta,
        verifiedSec.isAcceptableOrUnknown(
          data['verified_sec']!,
          _verifiedSecMeta,
        ),
      );
    }
    if (data.containsKey('final_state')) {
      context.handle(
        _finalStateMeta,
        finalState.isAcceptableOrUnknown(data['final_state']!, _finalStateMeta),
      );
    } else if (isInserting) {
      context.missing(_finalStateMeta);
    }
    if (data.containsKey('provenance')) {
      context.handle(
        _provenanceMeta,
        provenance.isAcceptableOrUnknown(data['provenance']!, _provenanceMeta),
      );
    } else if (isInserting) {
      context.missing(_provenanceMeta);
    }
    if (data.containsKey('factor_mask')) {
      context.handle(
        _factorMaskMeta,
        factorMask.isAcceptableOrUnknown(data['factor_mask']!, _factorMaskMeta),
      );
    }
    if (data.containsKey('track_enabled')) {
      context.handle(
        _trackEnabledMeta,
        trackEnabled.isAcceptableOrUnknown(
          data['track_enabled']!,
          _trackEnabledMeta,
        ),
      );
    }
    if (data.containsKey('violations')) {
      context.handle(
        _violationsMeta,
        violations.isAcceptableOrUnknown(data['violations']!, _violationsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      logicalDay: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logical_day'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      ),
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      blockName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category'],
      )!,
      plannedSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_sec'],
      )!,
      claimedSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}claimed_sec'],
      )!,
      verifiedSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}verified_sec'],
      )!,
      finalState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}final_state'],
      )!,
      provenance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}provenance'],
      )!,
      factorMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}factor_mask'],
      )!,
      trackEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_enabled'],
      )!,
      violations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}violations'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// The logical day (04:00 rollover applied), stored so day queries are a
  /// plain index lookup rather than arithmetic over every row.
  final DateTime logicalDay;
  final String? routineId;
  final String? blockId;
  final String? taskId;

  /// Denormalised on purpose: a session must still read correctly after its
  /// block has been edited or its routine deleted. History is not allowed to
  /// change retroactively.
  final String blockName;
  final int category;
  final int plannedSec;
  final int claimedSec;
  final int verifiedSec;

  /// Terminal [SessionState] index.
  final int finalState;

  /// [Provenance] index — untracked / app-verified / sensor-verified.
  final int provenance;

  /// Bitmask of [VerificationFactor]s that had a source. Without it, a report
  /// would compare a 3-factor day against a 1-factor day and say nothing.
  final int factorMask;
  final bool trackEnabled;
  final int violations;
  const Session({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.logicalDay,
    this.routineId,
    this.blockId,
    this.taskId,
    required this.blockName,
    required this.category,
    required this.plannedSec,
    required this.claimedSec,
    required this.verifiedSec,
    required this.finalState,
    required this.provenance,
    required this.factorMask,
    required this.trackEnabled,
    required this.violations,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['logical_day'] = Variable<DateTime>(logicalDay);
    if (!nullToAbsent || routineId != null) {
      map['routine_id'] = Variable<String>(routineId);
    }
    if (!nullToAbsent || blockId != null) {
      map['block_id'] = Variable<String>(blockId);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    map['block_name'] = Variable<String>(blockName);
    map['category'] = Variable<int>(category);
    map['planned_sec'] = Variable<int>(plannedSec);
    map['claimed_sec'] = Variable<int>(claimedSec);
    map['verified_sec'] = Variable<int>(verifiedSec);
    map['final_state'] = Variable<int>(finalState);
    map['provenance'] = Variable<int>(provenance);
    map['factor_mask'] = Variable<int>(factorMask);
    map['track_enabled'] = Variable<bool>(trackEnabled);
    map['violations'] = Variable<int>(violations);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      logicalDay: Value(logicalDay),
      routineId: routineId == null && nullToAbsent
          ? const Value.absent()
          : Value(routineId),
      blockId: blockId == null && nullToAbsent
          ? const Value.absent()
          : Value(blockId),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      blockName: Value(blockName),
      category: Value(category),
      plannedSec: Value(plannedSec),
      claimedSec: Value(claimedSec),
      verifiedSec: Value(verifiedSec),
      finalState: Value(finalState),
      provenance: Value(provenance),
      factorMask: Value(factorMask),
      trackEnabled: Value(trackEnabled),
      violations: Value(violations),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      logicalDay: serializer.fromJson<DateTime>(json['logicalDay']),
      routineId: serializer.fromJson<String?>(json['routineId']),
      blockId: serializer.fromJson<String?>(json['blockId']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      blockName: serializer.fromJson<String>(json['blockName']),
      category: serializer.fromJson<int>(json['category']),
      plannedSec: serializer.fromJson<int>(json['plannedSec']),
      claimedSec: serializer.fromJson<int>(json['claimedSec']),
      verifiedSec: serializer.fromJson<int>(json['verifiedSec']),
      finalState: serializer.fromJson<int>(json['finalState']),
      provenance: serializer.fromJson<int>(json['provenance']),
      factorMask: serializer.fromJson<int>(json['factorMask']),
      trackEnabled: serializer.fromJson<bool>(json['trackEnabled']),
      violations: serializer.fromJson<int>(json['violations']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'logicalDay': serializer.toJson<DateTime>(logicalDay),
      'routineId': serializer.toJson<String?>(routineId),
      'blockId': serializer.toJson<String?>(blockId),
      'taskId': serializer.toJson<String?>(taskId),
      'blockName': serializer.toJson<String>(blockName),
      'category': serializer.toJson<int>(category),
      'plannedSec': serializer.toJson<int>(plannedSec),
      'claimedSec': serializer.toJson<int>(claimedSec),
      'verifiedSec': serializer.toJson<int>(verifiedSec),
      'finalState': serializer.toJson<int>(finalState),
      'provenance': serializer.toJson<int>(provenance),
      'factorMask': serializer.toJson<int>(factorMask),
      'trackEnabled': serializer.toJson<bool>(trackEnabled),
      'violations': serializer.toJson<int>(violations),
    };
  }

  Session copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    DateTime? logicalDay,
    Value<String?> routineId = const Value.absent(),
    Value<String?> blockId = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    String? blockName,
    int? category,
    int? plannedSec,
    int? claimedSec,
    int? verifiedSec,
    int? finalState,
    int? provenance,
    int? factorMask,
    bool? trackEnabled,
    int? violations,
  }) => Session(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    logicalDay: logicalDay ?? this.logicalDay,
    routineId: routineId.present ? routineId.value : this.routineId,
    blockId: blockId.present ? blockId.value : this.blockId,
    taskId: taskId.present ? taskId.value : this.taskId,
    blockName: blockName ?? this.blockName,
    category: category ?? this.category,
    plannedSec: plannedSec ?? this.plannedSec,
    claimedSec: claimedSec ?? this.claimedSec,
    verifiedSec: verifiedSec ?? this.verifiedSec,
    finalState: finalState ?? this.finalState,
    provenance: provenance ?? this.provenance,
    factorMask: factorMask ?? this.factorMask,
    trackEnabled: trackEnabled ?? this.trackEnabled,
    violations: violations ?? this.violations,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      logicalDay: data.logicalDay.present
          ? data.logicalDay.value
          : this.logicalDay,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      blockName: data.blockName.present ? data.blockName.value : this.blockName,
      category: data.category.present ? data.category.value : this.category,
      plannedSec: data.plannedSec.present
          ? data.plannedSec.value
          : this.plannedSec,
      claimedSec: data.claimedSec.present
          ? data.claimedSec.value
          : this.claimedSec,
      verifiedSec: data.verifiedSec.present
          ? data.verifiedSec.value
          : this.verifiedSec,
      finalState: data.finalState.present
          ? data.finalState.value
          : this.finalState,
      provenance: data.provenance.present
          ? data.provenance.value
          : this.provenance,
      factorMask: data.factorMask.present
          ? data.factorMask.value
          : this.factorMask,
      trackEnabled: data.trackEnabled.present
          ? data.trackEnabled.value
          : this.trackEnabled,
      violations: data.violations.present
          ? data.violations.value
          : this.violations,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('logicalDay: $logicalDay, ')
          ..write('routineId: $routineId, ')
          ..write('blockId: $blockId, ')
          ..write('taskId: $taskId, ')
          ..write('blockName: $blockName, ')
          ..write('category: $category, ')
          ..write('plannedSec: $plannedSec, ')
          ..write('claimedSec: $claimedSec, ')
          ..write('verifiedSec: $verifiedSec, ')
          ..write('finalState: $finalState, ')
          ..write('provenance: $provenance, ')
          ..write('factorMask: $factorMask, ')
          ..write('trackEnabled: $trackEnabled, ')
          ..write('violations: $violations')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    logicalDay,
    routineId,
    blockId,
    taskId,
    blockName,
    category,
    plannedSec,
    claimedSec,
    verifiedSec,
    finalState,
    provenance,
    factorMask,
    trackEnabled,
    violations,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.logicalDay == this.logicalDay &&
          other.routineId == this.routineId &&
          other.blockId == this.blockId &&
          other.taskId == this.taskId &&
          other.blockName == this.blockName &&
          other.category == this.category &&
          other.plannedSec == this.plannedSec &&
          other.claimedSec == this.claimedSec &&
          other.verifiedSec == this.verifiedSec &&
          other.finalState == this.finalState &&
          other.provenance == this.provenance &&
          other.factorMask == this.factorMask &&
          other.trackEnabled == this.trackEnabled &&
          other.violations == this.violations);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<DateTime> logicalDay;
  final Value<String?> routineId;
  final Value<String?> blockId;
  final Value<String?> taskId;
  final Value<String> blockName;
  final Value<int> category;
  final Value<int> plannedSec;
  final Value<int> claimedSec;
  final Value<int> verifiedSec;
  final Value<int> finalState;
  final Value<int> provenance;
  final Value<int> factorMask;
  final Value<bool> trackEnabled;
  final Value<int> violations;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.logicalDay = const Value.absent(),
    this.routineId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.blockName = const Value.absent(),
    this.category = const Value.absent(),
    this.plannedSec = const Value.absent(),
    this.claimedSec = const Value.absent(),
    this.verifiedSec = const Value.absent(),
    this.finalState = const Value.absent(),
    this.provenance = const Value.absent(),
    this.factorMask = const Value.absent(),
    this.trackEnabled = const Value.absent(),
    this.violations = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required DateTime logicalDay,
    this.routineId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.taskId = const Value.absent(),
    required String blockName,
    required int category,
    required int plannedSec,
    this.claimedSec = const Value.absent(),
    this.verifiedSec = const Value.absent(),
    required int finalState,
    required int provenance,
    this.factorMask = const Value.absent(),
    this.trackEnabled = const Value.absent(),
    this.violations = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       logicalDay = Value(logicalDay),
       blockName = Value(blockName),
       category = Value(category),
       plannedSec = Value(plannedSec),
       finalState = Value(finalState),
       provenance = Value(provenance);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<DateTime>? logicalDay,
    Expression<String>? routineId,
    Expression<String>? blockId,
    Expression<String>? taskId,
    Expression<String>? blockName,
    Expression<int>? category,
    Expression<int>? plannedSec,
    Expression<int>? claimedSec,
    Expression<int>? verifiedSec,
    Expression<int>? finalState,
    Expression<int>? provenance,
    Expression<int>? factorMask,
    Expression<bool>? trackEnabled,
    Expression<int>? violations,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (logicalDay != null) 'logical_day': logicalDay,
      if (routineId != null) 'routine_id': routineId,
      if (blockId != null) 'block_id': blockId,
      if (taskId != null) 'task_id': taskId,
      if (blockName != null) 'block_name': blockName,
      if (category != null) 'category': category,
      if (plannedSec != null) 'planned_sec': plannedSec,
      if (claimedSec != null) 'claimed_sec': claimedSec,
      if (verifiedSec != null) 'verified_sec': verifiedSec,
      if (finalState != null) 'final_state': finalState,
      if (provenance != null) 'provenance': provenance,
      if (factorMask != null) 'factor_mask': factorMask,
      if (trackEnabled != null) 'track_enabled': trackEnabled,
      if (violations != null) 'violations': violations,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<DateTime>? logicalDay,
    Value<String?>? routineId,
    Value<String?>? blockId,
    Value<String?>? taskId,
    Value<String>? blockName,
    Value<int>? category,
    Value<int>? plannedSec,
    Value<int>? claimedSec,
    Value<int>? verifiedSec,
    Value<int>? finalState,
    Value<int>? provenance,
    Value<int>? factorMask,
    Value<bool>? trackEnabled,
    Value<int>? violations,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      logicalDay: logicalDay ?? this.logicalDay,
      routineId: routineId ?? this.routineId,
      blockId: blockId ?? this.blockId,
      taskId: taskId ?? this.taskId,
      blockName: blockName ?? this.blockName,
      category: category ?? this.category,
      plannedSec: plannedSec ?? this.plannedSec,
      claimedSec: claimedSec ?? this.claimedSec,
      verifiedSec: verifiedSec ?? this.verifiedSec,
      finalState: finalState ?? this.finalState,
      provenance: provenance ?? this.provenance,
      factorMask: factorMask ?? this.factorMask,
      trackEnabled: trackEnabled ?? this.trackEnabled,
      violations: violations ?? this.violations,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (logicalDay.present) {
      map['logical_day'] = Variable<DateTime>(logicalDay.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (blockName.present) {
      map['block_name'] = Variable<String>(blockName.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(category.value);
    }
    if (plannedSec.present) {
      map['planned_sec'] = Variable<int>(plannedSec.value);
    }
    if (claimedSec.present) {
      map['claimed_sec'] = Variable<int>(claimedSec.value);
    }
    if (verifiedSec.present) {
      map['verified_sec'] = Variable<int>(verifiedSec.value);
    }
    if (finalState.present) {
      map['final_state'] = Variable<int>(finalState.value);
    }
    if (provenance.present) {
      map['provenance'] = Variable<int>(provenance.value);
    }
    if (factorMask.present) {
      map['factor_mask'] = Variable<int>(factorMask.value);
    }
    if (trackEnabled.present) {
      map['track_enabled'] = Variable<bool>(trackEnabled.value);
    }
    if (violations.present) {
      map['violations'] = Variable<int>(violations.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('logicalDay: $logicalDay, ')
          ..write('routineId: $routineId, ')
          ..write('blockId: $blockId, ')
          ..write('taskId: $taskId, ')
          ..write('blockName: $blockName, ')
          ..write('category: $category, ')
          ..write('plannedSec: $plannedSec, ')
          ..write('claimedSec: $claimedSec, ')
          ..write('verifiedSec: $verifiedSec, ')
          ..write('finalState: $finalState, ')
          ..write('provenance: $provenance, ')
          ..write('factorMask: $factorMask, ')
          ..write('trackEnabled: $trackEnabled, ')
          ..write('violations: $violations, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionEventsTable extends SessionEvents
    with TableInfo<$SessionEventsTable, SessionEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromStateMeta = const VerificationMeta(
    'fromState',
  );
  @override
  late final GeneratedColumn<int> fromState = GeneratedColumn<int>(
    'from_state',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toStateMeta = const VerificationMeta(
    'toState',
  );
  @override
  late final GeneratedColumn<int> toState = GeneratedColumn<int>(
    'to_state',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<int> reason = GeneratedColumn<int>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _factorMaskMeta = const VerificationMeta(
    'factorMask',
  );
  @override
  late final GeneratedColumn<int> factorMask = GeneratedColumn<int>(
    'factor_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    at,
    kind,
    fromState,
    toState,
    reason,
    factorMask,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('from_state')) {
      context.handle(
        _fromStateMeta,
        fromState.isAcceptableOrUnknown(data['from_state']!, _fromStateMeta),
      );
    }
    if (data.containsKey('to_state')) {
      context.handle(
        _toStateMeta,
        toState.isAcceptableOrUnknown(data['to_state']!, _toStateMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('factor_mask')) {
      context.handle(
        _factorMaskMeta,
        factorMask.isAcceptableOrUnknown(data['factor_mask']!, _factorMaskMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      fromState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_state'],
      ),
      toState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_state'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reason'],
      ),
      factorMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}factor_mask'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
    );
  }

  @override
  $SessionEventsTable createAlias(String alias) {
    return $SessionEventsTable(attachedDatabase, alias);
  }
}

class SessionEventRow extends DataClass implements Insertable<SessionEventRow> {
  final String id;
  final String sessionId;
  final DateTime at;

  /// 0 transition · 1 violation · 2 note
  final int kind;
  final int? fromState;
  final int? toState;

  /// [ViolationReason] index.
  final int? reason;

  /// Bitmask of the factors that were violating.
  final int factorMask;
  final String detail;
  const SessionEventRow({
    required this.id,
    required this.sessionId,
    required this.at,
    required this.kind,
    this.fromState,
    this.toState,
    this.reason,
    required this.factorMask,
    required this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['at'] = Variable<DateTime>(at);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || fromState != null) {
      map['from_state'] = Variable<int>(fromState);
    }
    if (!nullToAbsent || toState != null) {
      map['to_state'] = Variable<int>(toState);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<int>(reason);
    }
    map['factor_mask'] = Variable<int>(factorMask);
    map['detail'] = Variable<String>(detail);
    return map;
  }

  SessionEventsCompanion toCompanion(bool nullToAbsent) {
    return SessionEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      at: Value(at),
      kind: Value(kind),
      fromState: fromState == null && nullToAbsent
          ? const Value.absent()
          : Value(fromState),
      toState: toState == null && nullToAbsent
          ? const Value.absent()
          : Value(toState),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      factorMask: Value(factorMask),
      detail: Value(detail),
    );
  }

  factory SessionEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionEventRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      at: serializer.fromJson<DateTime>(json['at']),
      kind: serializer.fromJson<int>(json['kind']),
      fromState: serializer.fromJson<int?>(json['fromState']),
      toState: serializer.fromJson<int?>(json['toState']),
      reason: serializer.fromJson<int?>(json['reason']),
      factorMask: serializer.fromJson<int>(json['factorMask']),
      detail: serializer.fromJson<String>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'at': serializer.toJson<DateTime>(at),
      'kind': serializer.toJson<int>(kind),
      'fromState': serializer.toJson<int?>(fromState),
      'toState': serializer.toJson<int?>(toState),
      'reason': serializer.toJson<int?>(reason),
      'factorMask': serializer.toJson<int>(factorMask),
      'detail': serializer.toJson<String>(detail),
    };
  }

  SessionEventRow copyWith({
    String? id,
    String? sessionId,
    DateTime? at,
    int? kind,
    Value<int?> fromState = const Value.absent(),
    Value<int?> toState = const Value.absent(),
    Value<int?> reason = const Value.absent(),
    int? factorMask,
    String? detail,
  }) => SessionEventRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    at: at ?? this.at,
    kind: kind ?? this.kind,
    fromState: fromState.present ? fromState.value : this.fromState,
    toState: toState.present ? toState.value : this.toState,
    reason: reason.present ? reason.value : this.reason,
    factorMask: factorMask ?? this.factorMask,
    detail: detail ?? this.detail,
  );
  SessionEventRow copyWithCompanion(SessionEventsCompanion data) {
    return SessionEventRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      at: data.at.present ? data.at.value : this.at,
      kind: data.kind.present ? data.kind.value : this.kind,
      fromState: data.fromState.present ? data.fromState.value : this.fromState,
      toState: data.toState.present ? data.toState.value : this.toState,
      reason: data.reason.present ? data.reason.value : this.reason,
      factorMask: data.factorMask.present
          ? data.factorMask.value
          : this.factorMask,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionEventRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('fromState: $fromState, ')
          ..write('toState: $toState, ')
          ..write('reason: $reason, ')
          ..write('factorMask: $factorMask, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    at,
    kind,
    fromState,
    toState,
    reason,
    factorMask,
    detail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionEventRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.at == this.at &&
          other.kind == this.kind &&
          other.fromState == this.fromState &&
          other.toState == this.toState &&
          other.reason == this.reason &&
          other.factorMask == this.factorMask &&
          other.detail == this.detail);
}

class SessionEventsCompanion extends UpdateCompanion<SessionEventRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<DateTime> at;
  final Value<int> kind;
  final Value<int?> fromState;
  final Value<int?> toState;
  final Value<int?> reason;
  final Value<int> factorMask;
  final Value<String> detail;
  final Value<int> rowid;
  const SessionEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.at = const Value.absent(),
    this.kind = const Value.absent(),
    this.fromState = const Value.absent(),
    this.toState = const Value.absent(),
    this.reason = const Value.absent(),
    this.factorMask = const Value.absent(),
    this.detail = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionEventsCompanion.insert({
    required String id,
    required String sessionId,
    required DateTime at,
    required int kind,
    this.fromState = const Value.absent(),
    this.toState = const Value.absent(),
    this.reason = const Value.absent(),
    this.factorMask = const Value.absent(),
    this.detail = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       at = Value(at),
       kind = Value(kind);
  static Insertable<SessionEventRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? at,
    Expression<int>? kind,
    Expression<int>? fromState,
    Expression<int>? toState,
    Expression<int>? reason,
    Expression<int>? factorMask,
    Expression<String>? detail,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (at != null) 'at': at,
      if (kind != null) 'kind': kind,
      if (fromState != null) 'from_state': fromState,
      if (toState != null) 'to_state': toState,
      if (reason != null) 'reason': reason,
      if (factorMask != null) 'factor_mask': factorMask,
      if (detail != null) 'detail': detail,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<DateTime>? at,
    Value<int>? kind,
    Value<int?>? fromState,
    Value<int?>? toState,
    Value<int?>? reason,
    Value<int>? factorMask,
    Value<String>? detail,
    Value<int>? rowid,
  }) {
    return SessionEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      at: at ?? this.at,
      kind: kind ?? this.kind,
      fromState: fromState ?? this.fromState,
      toState: toState ?? this.toState,
      reason: reason ?? this.reason,
      factorMask: factorMask ?? this.factorMask,
      detail: detail ?? this.detail,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (fromState.present) {
      map['from_state'] = Variable<int>(fromState.value);
    }
    if (toState.present) {
      map['to_state'] = Variable<int>(toState.value);
    }
    if (reason.present) {
      map['reason'] = Variable<int>(reason.value);
    }
    if (factorMask.present) {
      map['factor_mask'] = Variable<int>(factorMask.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('fromState: $fromState, ')
          ..write('toState: $toState, ')
          ..write('reason: $reason, ')
          ..write('factorMask: $factorMask, ')
          ..write('detail: $detail, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayLogsTable extends DayLogs with TableInfo<$DayLogsTable, DayLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifiedMinMeta = const VerificationMeta(
    'verifiedMin',
  );
  @override
  late final GeneratedColumn<int> verifiedMin = GeneratedColumn<int>(
    'verified_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _claimedMinMeta = const VerificationMeta(
    'claimedMin',
  );
  @override
  late final GeneratedColumn<int> claimedMin = GeneratedColumn<int>(
    'claimed_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blocksDoneMeta = const VerificationMeta(
    'blocksDone',
  );
  @override
  late final GeneratedColumn<int> blocksDone = GeneratedColumn<int>(
    'blocks_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blocksTotalMeta = const VerificationMeta(
    'blocksTotal',
  );
  @override
  late final GeneratedColumn<int> blocksTotal = GeneratedColumn<int>(
    'blocks_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _violationsMeta = const VerificationMeta(
    'violations',
  );
  @override
  late final GeneratedColumn<int> violations = GeneratedColumn<int>(
    'violations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<int> source = GeneratedColumn<int>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    verifiedMin,
    claimedMin,
    blocksDone,
    blocksTotal,
    violations,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('verified_min')) {
      context.handle(
        _verifiedMinMeta,
        verifiedMin.isAcceptableOrUnknown(
          data['verified_min']!,
          _verifiedMinMeta,
        ),
      );
    }
    if (data.containsKey('claimed_min')) {
      context.handle(
        _claimedMinMeta,
        claimedMin.isAcceptableOrUnknown(data['claimed_min']!, _claimedMinMeta),
      );
    }
    if (data.containsKey('blocks_done')) {
      context.handle(
        _blocksDoneMeta,
        blocksDone.isAcceptableOrUnknown(data['blocks_done']!, _blocksDoneMeta),
      );
    }
    if (data.containsKey('blocks_total')) {
      context.handle(
        _blocksTotalMeta,
        blocksTotal.isAcceptableOrUnknown(
          data['blocks_total']!,
          _blocksTotalMeta,
        ),
      );
    }
    if (data.containsKey('violations')) {
      context.handle(
        _violationsMeta,
        violations.isAcceptableOrUnknown(data['violations']!, _violationsMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DayLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayLog(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day'],
      )!,
      verifiedMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}verified_min'],
      )!,
      claimedMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}claimed_min'],
      )!,
      blocksDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocks_done'],
      )!,
      blocksTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocks_total'],
      )!,
      violations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}violations'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $DayLogsTable createAlias(String alias) {
    return $DayLogsTable(attachedDatabase, alias);
  }
}

class DayLog extends DataClass implements Insertable<DayLog> {
  final DateTime day;
  final int verifiedMin;
  final int claimedMin;
  final int blocksDone;
  final int blocksTotal;
  final int violations;

  /// 0 app · 1 device · 2 merged. Kept so a device pull never silently
  /// overwrites richer app-side data.
  final int source;
  const DayLog({
    required this.day,
    required this.verifiedMin,
    required this.claimedMin,
    required this.blocksDone,
    required this.blocksTotal,
    required this.violations,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<DateTime>(day);
    map['verified_min'] = Variable<int>(verifiedMin);
    map['claimed_min'] = Variable<int>(claimedMin);
    map['blocks_done'] = Variable<int>(blocksDone);
    map['blocks_total'] = Variable<int>(blocksTotal);
    map['violations'] = Variable<int>(violations);
    map['source'] = Variable<int>(source);
    return map;
  }

  DayLogsCompanion toCompanion(bool nullToAbsent) {
    return DayLogsCompanion(
      day: Value(day),
      verifiedMin: Value(verifiedMin),
      claimedMin: Value(claimedMin),
      blocksDone: Value(blocksDone),
      blocksTotal: Value(blocksTotal),
      violations: Value(violations),
      source: Value(source),
    );
  }

  factory DayLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayLog(
      day: serializer.fromJson<DateTime>(json['day']),
      verifiedMin: serializer.fromJson<int>(json['verifiedMin']),
      claimedMin: serializer.fromJson<int>(json['claimedMin']),
      blocksDone: serializer.fromJson<int>(json['blocksDone']),
      blocksTotal: serializer.fromJson<int>(json['blocksTotal']),
      violations: serializer.fromJson<int>(json['violations']),
      source: serializer.fromJson<int>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<DateTime>(day),
      'verifiedMin': serializer.toJson<int>(verifiedMin),
      'claimedMin': serializer.toJson<int>(claimedMin),
      'blocksDone': serializer.toJson<int>(blocksDone),
      'blocksTotal': serializer.toJson<int>(blocksTotal),
      'violations': serializer.toJson<int>(violations),
      'source': serializer.toJson<int>(source),
    };
  }

  DayLog copyWith({
    DateTime? day,
    int? verifiedMin,
    int? claimedMin,
    int? blocksDone,
    int? blocksTotal,
    int? violations,
    int? source,
  }) => DayLog(
    day: day ?? this.day,
    verifiedMin: verifiedMin ?? this.verifiedMin,
    claimedMin: claimedMin ?? this.claimedMin,
    blocksDone: blocksDone ?? this.blocksDone,
    blocksTotal: blocksTotal ?? this.blocksTotal,
    violations: violations ?? this.violations,
    source: source ?? this.source,
  );
  DayLog copyWithCompanion(DayLogsCompanion data) {
    return DayLog(
      day: data.day.present ? data.day.value : this.day,
      verifiedMin: data.verifiedMin.present
          ? data.verifiedMin.value
          : this.verifiedMin,
      claimedMin: data.claimedMin.present
          ? data.claimedMin.value
          : this.claimedMin,
      blocksDone: data.blocksDone.present
          ? data.blocksDone.value
          : this.blocksDone,
      blocksTotal: data.blocksTotal.present
          ? data.blocksTotal.value
          : this.blocksTotal,
      violations: data.violations.present
          ? data.violations.value
          : this.violations,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayLog(')
          ..write('day: $day, ')
          ..write('verifiedMin: $verifiedMin, ')
          ..write('claimedMin: $claimedMin, ')
          ..write('blocksDone: $blocksDone, ')
          ..write('blocksTotal: $blocksTotal, ')
          ..write('violations: $violations, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    day,
    verifiedMin,
    claimedMin,
    blocksDone,
    blocksTotal,
    violations,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayLog &&
          other.day == this.day &&
          other.verifiedMin == this.verifiedMin &&
          other.claimedMin == this.claimedMin &&
          other.blocksDone == this.blocksDone &&
          other.blocksTotal == this.blocksTotal &&
          other.violations == this.violations &&
          other.source == this.source);
}

class DayLogsCompanion extends UpdateCompanion<DayLog> {
  final Value<DateTime> day;
  final Value<int> verifiedMin;
  final Value<int> claimedMin;
  final Value<int> blocksDone;
  final Value<int> blocksTotal;
  final Value<int> violations;
  final Value<int> source;
  final Value<int> rowid;
  const DayLogsCompanion({
    this.day = const Value.absent(),
    this.verifiedMin = const Value.absent(),
    this.claimedMin = const Value.absent(),
    this.blocksDone = const Value.absent(),
    this.blocksTotal = const Value.absent(),
    this.violations = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayLogsCompanion.insert({
    required DateTime day,
    this.verifiedMin = const Value.absent(),
    this.claimedMin = const Value.absent(),
    this.blocksDone = const Value.absent(),
    this.blocksTotal = const Value.absent(),
    this.violations = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day);
  static Insertable<DayLog> custom({
    Expression<DateTime>? day,
    Expression<int>? verifiedMin,
    Expression<int>? claimedMin,
    Expression<int>? blocksDone,
    Expression<int>? blocksTotal,
    Expression<int>? violations,
    Expression<int>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (verifiedMin != null) 'verified_min': verifiedMin,
      if (claimedMin != null) 'claimed_min': claimedMin,
      if (blocksDone != null) 'blocks_done': blocksDone,
      if (blocksTotal != null) 'blocks_total': blocksTotal,
      if (violations != null) 'violations': violations,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayLogsCompanion copyWith({
    Value<DateTime>? day,
    Value<int>? verifiedMin,
    Value<int>? claimedMin,
    Value<int>? blocksDone,
    Value<int>? blocksTotal,
    Value<int>? violations,
    Value<int>? source,
    Value<int>? rowid,
  }) {
    return DayLogsCompanion(
      day: day ?? this.day,
      verifiedMin: verifiedMin ?? this.verifiedMin,
      claimedMin: claimedMin ?? this.claimedMin,
      blocksDone: blocksDone ?? this.blocksDone,
      blocksTotal: blocksTotal ?? this.blocksTotal,
      violations: violations ?? this.violations,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (verifiedMin.present) {
      map['verified_min'] = Variable<int>(verifiedMin.value);
    }
    if (claimedMin.present) {
      map['claimed_min'] = Variable<int>(claimedMin.value);
    }
    if (blocksDone.present) {
      map['blocks_done'] = Variable<int>(blocksDone.value);
    }
    if (blocksTotal.present) {
      map['blocks_total'] = Variable<int>(blocksTotal.value);
    }
    if (violations.present) {
      map['violations'] = Variable<int>(violations.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayLogsCompanion(')
          ..write('day: $day, ')
          ..write('verifiedMin: $verifiedMin, ')
          ..write('claimedMin: $claimedMin, ')
          ..write('blocksDone: $blocksDone, ')
          ..write('blocksTotal: $blocksTotal, ')
          ..write('violations: $violations, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceProfilesTable extends DeviceProfiles
    with TableInfo<$DeviceProfilesTable, DeviceProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protoVersionMeta = const VerificationMeta(
    'protoVersion',
  );
  @override
  late final GeneratedColumn<int> protoVersion = GeneratedColumn<int>(
    'proto_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fwMajorMeta = const VerificationMeta(
    'fwMajor',
  );
  @override
  late final GeneratedColumn<int> fwMajor = GeneratedColumn<int>(
    'fw_major',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fwMinorMeta = const VerificationMeta(
    'fwMinor',
  );
  @override
  late final GeneratedColumn<int> fwMinor = GeneratedColumn<int>(
    'fw_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<int> deviceId = GeneratedColumn<int>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _capsLoMeta = const VerificationMeta('capsLo');
  @override
  late final GeneratedColumn<int> capsLo = GeneratedColumn<int>(
    'caps_lo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _capsHiMeta = const VerificationMeta('capsHi');
  @override
  late final GeneratedColumn<int> capsHi = GeneratedColumn<int>(
    'caps_hi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _eepromLogDaysMeta = const VerificationMeta(
    'eepromLogDays',
  );
  @override
  late final GeneratedColumn<int> eepromLogDays = GeneratedColumn<int>(
    'eeprom_log_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _maxBlocksMeta = const VerificationMeta(
    'maxBlocks',
  );
  @override
  late final GeneratedColumn<int> maxBlocks = GeneratedColumn<int>(
    'max_blocks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(16),
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoConnectMeta = const VerificationMeta(
    'autoConnect',
  );
  @override
  late final GeneratedColumn<bool> autoConnect = GeneratedColumn<bool>(
    'auto_connect',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_connect" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    address,
    name,
    protoVersion,
    fwMajor,
    fwMinor,
    deviceId,
    capsLo,
    capsHi,
    eepromLogDays,
    maxBlocks,
    lastSeenAt,
    autoConnect,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('proto_version')) {
      context.handle(
        _protoVersionMeta,
        protoVersion.isAcceptableOrUnknown(
          data['proto_version']!,
          _protoVersionMeta,
        ),
      );
    }
    if (data.containsKey('fw_major')) {
      context.handle(
        _fwMajorMeta,
        fwMajor.isAcceptableOrUnknown(data['fw_major']!, _fwMajorMeta),
      );
    }
    if (data.containsKey('fw_minor')) {
      context.handle(
        _fwMinorMeta,
        fwMinor.isAcceptableOrUnknown(data['fw_minor']!, _fwMinorMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('caps_lo')) {
      context.handle(
        _capsLoMeta,
        capsLo.isAcceptableOrUnknown(data['caps_lo']!, _capsLoMeta),
      );
    }
    if (data.containsKey('caps_hi')) {
      context.handle(
        _capsHiMeta,
        capsHi.isAcceptableOrUnknown(data['caps_hi']!, _capsHiMeta),
      );
    }
    if (data.containsKey('eeprom_log_days')) {
      context.handle(
        _eepromLogDaysMeta,
        eepromLogDays.isAcceptableOrUnknown(
          data['eeprom_log_days']!,
          _eepromLogDaysMeta,
        ),
      );
    }
    if (data.containsKey('max_blocks')) {
      context.handle(
        _maxBlocksMeta,
        maxBlocks.isAcceptableOrUnknown(data['max_blocks']!, _maxBlocksMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('auto_connect')) {
      context.handle(
        _autoConnectMeta,
        autoConnect.isAcceptableOrUnknown(
          data['auto_connect']!,
          _autoConnectMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {address};
  @override
  DeviceProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceProfile(
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      protoVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proto_version'],
      )!,
      fwMajor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fw_major'],
      )!,
      fwMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fw_minor'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_id'],
      )!,
      capsLo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}caps_lo'],
      )!,
      capsHi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}caps_hi'],
      )!,
      eepromLogDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eeprom_log_days'],
      )!,
      maxBlocks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_blocks'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      ),
      autoConnect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_connect'],
      )!,
    );
  }

  @override
  $DeviceProfilesTable createAlias(String alias) {
    return $DeviceProfilesTable(attachedDatabase, alias);
  }
}

class DeviceProfile extends DataClass implements Insertable<DeviceProfile> {
  final String address;
  final String name;
  final int protoVersion;
  final int fwMajor;
  final int fwMinor;
  final int deviceId;
  final int capsLo;
  final int capsHi;
  final int eepromLogDays;
  final int maxBlocks;
  final DateTime? lastSeenAt;
  final bool autoConnect;
  const DeviceProfile({
    required this.address,
    required this.name,
    required this.protoVersion,
    required this.fwMajor,
    required this.fwMinor,
    required this.deviceId,
    required this.capsLo,
    required this.capsHi,
    required this.eepromLogDays,
    required this.maxBlocks,
    this.lastSeenAt,
    required this.autoConnect,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['address'] = Variable<String>(address);
    map['name'] = Variable<String>(name);
    map['proto_version'] = Variable<int>(protoVersion);
    map['fw_major'] = Variable<int>(fwMajor);
    map['fw_minor'] = Variable<int>(fwMinor);
    map['device_id'] = Variable<int>(deviceId);
    map['caps_lo'] = Variable<int>(capsLo);
    map['caps_hi'] = Variable<int>(capsHi);
    map['eeprom_log_days'] = Variable<int>(eepromLogDays);
    map['max_blocks'] = Variable<int>(maxBlocks);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    map['auto_connect'] = Variable<bool>(autoConnect);
    return map;
  }

  DeviceProfilesCompanion toCompanion(bool nullToAbsent) {
    return DeviceProfilesCompanion(
      address: Value(address),
      name: Value(name),
      protoVersion: Value(protoVersion),
      fwMajor: Value(fwMajor),
      fwMinor: Value(fwMinor),
      deviceId: Value(deviceId),
      capsLo: Value(capsLo),
      capsHi: Value(capsHi),
      eepromLogDays: Value(eepromLogDays),
      maxBlocks: Value(maxBlocks),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      autoConnect: Value(autoConnect),
    );
  }

  factory DeviceProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceProfile(
      address: serializer.fromJson<String>(json['address']),
      name: serializer.fromJson<String>(json['name']),
      protoVersion: serializer.fromJson<int>(json['protoVersion']),
      fwMajor: serializer.fromJson<int>(json['fwMajor']),
      fwMinor: serializer.fromJson<int>(json['fwMinor']),
      deviceId: serializer.fromJson<int>(json['deviceId']),
      capsLo: serializer.fromJson<int>(json['capsLo']),
      capsHi: serializer.fromJson<int>(json['capsHi']),
      eepromLogDays: serializer.fromJson<int>(json['eepromLogDays']),
      maxBlocks: serializer.fromJson<int>(json['maxBlocks']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
      autoConnect: serializer.fromJson<bool>(json['autoConnect']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'address': serializer.toJson<String>(address),
      'name': serializer.toJson<String>(name),
      'protoVersion': serializer.toJson<int>(protoVersion),
      'fwMajor': serializer.toJson<int>(fwMajor),
      'fwMinor': serializer.toJson<int>(fwMinor),
      'deviceId': serializer.toJson<int>(deviceId),
      'capsLo': serializer.toJson<int>(capsLo),
      'capsHi': serializer.toJson<int>(capsHi),
      'eepromLogDays': serializer.toJson<int>(eepromLogDays),
      'maxBlocks': serializer.toJson<int>(maxBlocks),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
      'autoConnect': serializer.toJson<bool>(autoConnect),
    };
  }

  DeviceProfile copyWith({
    String? address,
    String? name,
    int? protoVersion,
    int? fwMajor,
    int? fwMinor,
    int? deviceId,
    int? capsLo,
    int? capsHi,
    int? eepromLogDays,
    int? maxBlocks,
    Value<DateTime?> lastSeenAt = const Value.absent(),
    bool? autoConnect,
  }) => DeviceProfile(
    address: address ?? this.address,
    name: name ?? this.name,
    protoVersion: protoVersion ?? this.protoVersion,
    fwMajor: fwMajor ?? this.fwMajor,
    fwMinor: fwMinor ?? this.fwMinor,
    deviceId: deviceId ?? this.deviceId,
    capsLo: capsLo ?? this.capsLo,
    capsHi: capsHi ?? this.capsHi,
    eepromLogDays: eepromLogDays ?? this.eepromLogDays,
    maxBlocks: maxBlocks ?? this.maxBlocks,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    autoConnect: autoConnect ?? this.autoConnect,
  );
  DeviceProfile copyWithCompanion(DeviceProfilesCompanion data) {
    return DeviceProfile(
      address: data.address.present ? data.address.value : this.address,
      name: data.name.present ? data.name.value : this.name,
      protoVersion: data.protoVersion.present
          ? data.protoVersion.value
          : this.protoVersion,
      fwMajor: data.fwMajor.present ? data.fwMajor.value : this.fwMajor,
      fwMinor: data.fwMinor.present ? data.fwMinor.value : this.fwMinor,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      capsLo: data.capsLo.present ? data.capsLo.value : this.capsLo,
      capsHi: data.capsHi.present ? data.capsHi.value : this.capsHi,
      eepromLogDays: data.eepromLogDays.present
          ? data.eepromLogDays.value
          : this.eepromLogDays,
      maxBlocks: data.maxBlocks.present ? data.maxBlocks.value : this.maxBlocks,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      autoConnect: data.autoConnect.present
          ? data.autoConnect.value
          : this.autoConnect,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceProfile(')
          ..write('address: $address, ')
          ..write('name: $name, ')
          ..write('protoVersion: $protoVersion, ')
          ..write('fwMajor: $fwMajor, ')
          ..write('fwMinor: $fwMinor, ')
          ..write('deviceId: $deviceId, ')
          ..write('capsLo: $capsLo, ')
          ..write('capsHi: $capsHi, ')
          ..write('eepromLogDays: $eepromLogDays, ')
          ..write('maxBlocks: $maxBlocks, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('autoConnect: $autoConnect')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    address,
    name,
    protoVersion,
    fwMajor,
    fwMinor,
    deviceId,
    capsLo,
    capsHi,
    eepromLogDays,
    maxBlocks,
    lastSeenAt,
    autoConnect,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceProfile &&
          other.address == this.address &&
          other.name == this.name &&
          other.protoVersion == this.protoVersion &&
          other.fwMajor == this.fwMajor &&
          other.fwMinor == this.fwMinor &&
          other.deviceId == this.deviceId &&
          other.capsLo == this.capsLo &&
          other.capsHi == this.capsHi &&
          other.eepromLogDays == this.eepromLogDays &&
          other.maxBlocks == this.maxBlocks &&
          other.lastSeenAt == this.lastSeenAt &&
          other.autoConnect == this.autoConnect);
}

class DeviceProfilesCompanion extends UpdateCompanion<DeviceProfile> {
  final Value<String> address;
  final Value<String> name;
  final Value<int> protoVersion;
  final Value<int> fwMajor;
  final Value<int> fwMinor;
  final Value<int> deviceId;
  final Value<int> capsLo;
  final Value<int> capsHi;
  final Value<int> eepromLogDays;
  final Value<int> maxBlocks;
  final Value<DateTime?> lastSeenAt;
  final Value<bool> autoConnect;
  final Value<int> rowid;
  const DeviceProfilesCompanion({
    this.address = const Value.absent(),
    this.name = const Value.absent(),
    this.protoVersion = const Value.absent(),
    this.fwMajor = const Value.absent(),
    this.fwMinor = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.capsLo = const Value.absent(),
    this.capsHi = const Value.absent(),
    this.eepromLogDays = const Value.absent(),
    this.maxBlocks = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.autoConnect = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceProfilesCompanion.insert({
    required String address,
    required String name,
    this.protoVersion = const Value.absent(),
    this.fwMajor = const Value.absent(),
    this.fwMinor = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.capsLo = const Value.absent(),
    this.capsHi = const Value.absent(),
    this.eepromLogDays = const Value.absent(),
    this.maxBlocks = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.autoConnect = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : address = Value(address),
       name = Value(name);
  static Insertable<DeviceProfile> custom({
    Expression<String>? address,
    Expression<String>? name,
    Expression<int>? protoVersion,
    Expression<int>? fwMajor,
    Expression<int>? fwMinor,
    Expression<int>? deviceId,
    Expression<int>? capsLo,
    Expression<int>? capsHi,
    Expression<int>? eepromLogDays,
    Expression<int>? maxBlocks,
    Expression<DateTime>? lastSeenAt,
    Expression<bool>? autoConnect,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (address != null) 'address': address,
      if (name != null) 'name': name,
      if (protoVersion != null) 'proto_version': protoVersion,
      if (fwMajor != null) 'fw_major': fwMajor,
      if (fwMinor != null) 'fw_minor': fwMinor,
      if (deviceId != null) 'device_id': deviceId,
      if (capsLo != null) 'caps_lo': capsLo,
      if (capsHi != null) 'caps_hi': capsHi,
      if (eepromLogDays != null) 'eeprom_log_days': eepromLogDays,
      if (maxBlocks != null) 'max_blocks': maxBlocks,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (autoConnect != null) 'auto_connect': autoConnect,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceProfilesCompanion copyWith({
    Value<String>? address,
    Value<String>? name,
    Value<int>? protoVersion,
    Value<int>? fwMajor,
    Value<int>? fwMinor,
    Value<int>? deviceId,
    Value<int>? capsLo,
    Value<int>? capsHi,
    Value<int>? eepromLogDays,
    Value<int>? maxBlocks,
    Value<DateTime?>? lastSeenAt,
    Value<bool>? autoConnect,
    Value<int>? rowid,
  }) {
    return DeviceProfilesCompanion(
      address: address ?? this.address,
      name: name ?? this.name,
      protoVersion: protoVersion ?? this.protoVersion,
      fwMajor: fwMajor ?? this.fwMajor,
      fwMinor: fwMinor ?? this.fwMinor,
      deviceId: deviceId ?? this.deviceId,
      capsLo: capsLo ?? this.capsLo,
      capsHi: capsHi ?? this.capsHi,
      eepromLogDays: eepromLogDays ?? this.eepromLogDays,
      maxBlocks: maxBlocks ?? this.maxBlocks,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      autoConnect: autoConnect ?? this.autoConnect,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (protoVersion.present) {
      map['proto_version'] = Variable<int>(protoVersion.value);
    }
    if (fwMajor.present) {
      map['fw_major'] = Variable<int>(fwMajor.value);
    }
    if (fwMinor.present) {
      map['fw_minor'] = Variable<int>(fwMinor.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<int>(deviceId.value);
    }
    if (capsLo.present) {
      map['caps_lo'] = Variable<int>(capsLo.value);
    }
    if (capsHi.present) {
      map['caps_hi'] = Variable<int>(capsHi.value);
    }
    if (eepromLogDays.present) {
      map['eeprom_log_days'] = Variable<int>(eepromLogDays.value);
    }
    if (maxBlocks.present) {
      map['max_blocks'] = Variable<int>(maxBlocks.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (autoConnect.present) {
      map['auto_connect'] = Variable<bool>(autoConnect.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceProfilesCompanion(')
          ..write('address: $address, ')
          ..write('name: $name, ')
          ..write('protoVersion: $protoVersion, ')
          ..write('fwMajor: $fwMajor, ')
          ..write('fwMinor: $fwMinor, ')
          ..write('deviceId: $deviceId, ')
          ..write('capsLo: $capsLo, ')
          ..write('capsHi: $capsHi, ')
          ..write('eepromLogDays: $eepromLogDays, ')
          ..write('maxBlocks: $maxBlocks, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('autoConnect: $autoConnect, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AchievementsTable extends Achievements
    with TableInfo<$AchievementsTable, AchievementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unlockedAtMeta = const VerificationMeta(
    'unlockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
    'unlocked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, progress, unlockedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievements';
  @override
  VerificationContext validateIntegrity(
    Insertable<AchievementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
        _unlockedAtMeta,
        unlockedAt.isAcceptableOrUnknown(data['unlocked_at']!, _unlockedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AchievementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AchievementRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress'],
      )!,
      unlockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}unlocked_at'],
      ),
    );
  }

  @override
  $AchievementsTable createAlias(String alias) {
    return $AchievementsTable(attachedDatabase, alias);
  }
}

class AchievementRow extends DataClass implements Insertable<AchievementRow> {
  final String key;
  final int progress;
  final DateTime? unlockedAt;
  const AchievementRow({
    required this.key,
    required this.progress,
    this.unlockedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['progress'] = Variable<int>(progress);
    if (!nullToAbsent || unlockedAt != null) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    }
    return map;
  }

  AchievementsCompanion toCompanion(bool nullToAbsent) {
    return AchievementsCompanion(
      key: Value(key),
      progress: Value(progress),
      unlockedAt: unlockedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(unlockedAt),
    );
  }

  factory AchievementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AchievementRow(
      key: serializer.fromJson<String>(json['key']),
      progress: serializer.fromJson<int>(json['progress']),
      unlockedAt: serializer.fromJson<DateTime?>(json['unlockedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'progress': serializer.toJson<int>(progress),
      'unlockedAt': serializer.toJson<DateTime?>(unlockedAt),
    };
  }

  AchievementRow copyWith({
    String? key,
    int? progress,
    Value<DateTime?> unlockedAt = const Value.absent(),
  }) => AchievementRow(
    key: key ?? this.key,
    progress: progress ?? this.progress,
    unlockedAt: unlockedAt.present ? unlockedAt.value : this.unlockedAt,
  );
  AchievementRow copyWithCompanion(AchievementsCompanion data) {
    return AchievementRow(
      key: data.key.present ? data.key.value : this.key,
      progress: data.progress.present ? data.progress.value : this.progress,
      unlockedAt: data.unlockedAt.present
          ? data.unlockedAt.value
          : this.unlockedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AchievementRow(')
          ..write('key: $key, ')
          ..write('progress: $progress, ')
          ..write('unlockedAt: $unlockedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, progress, unlockedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AchievementRow &&
          other.key == this.key &&
          other.progress == this.progress &&
          other.unlockedAt == this.unlockedAt);
}

class AchievementsCompanion extends UpdateCompanion<AchievementRow> {
  final Value<String> key;
  final Value<int> progress;
  final Value<DateTime?> unlockedAt;
  final Value<int> rowid;
  const AchievementsCompanion({
    this.key = const Value.absent(),
    this.progress = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AchievementsCompanion.insert({
    required String key,
    this.progress = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AchievementRow> custom({
    Expression<String>? key,
    Expression<int>? progress,
    Expression<DateTime>? unlockedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (progress != null) 'progress': progress,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AchievementsCompanion copyWith({
    Value<String>? key,
    Value<int>? progress,
    Value<DateTime?>? unlockedAt,
    Value<int>? rowid,
  }) {
    return AchievementsCompanion(
      key: key ?? this.key,
      progress: progress ?? this.progress,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsCompanion(')
          ..write('key: $key, ')
          ..write('progress: $progress, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  late final $BlocksTable blocks = $BlocksTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $SubtasksTable subtasks = $SubtasksTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TaskTagsTable taskTags = $TaskTagsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionEventsTable sessionEvents = $SessionEventsTable(this);
  late final $DayLogsTable dayLogs = $DayLogsTable(this);
  late final $DeviceProfilesTable deviceProfiles = $DeviceProfilesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $AchievementsTable achievements = $AchievementsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    routines,
    blocks,
    tasks,
    subtasks,
    tags,
    taskTags,
    sessions,
    sessionEvents,
    dayLogs,
    deviceProfiles,
    appSettings,
    achievements,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('blocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('subtasks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RoutinesTableCreateCompanionBuilder =
    RoutinesCompanion Function({
      required String id,
      required String name,
      Value<String> description,
      Value<bool> isBuiltIn,
      Value<String?> templateKey,
      Value<int> sortOrder,
      Value<bool> archived,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RoutinesTableUpdateCompanionBuilder =
    RoutinesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<bool> isBuiltIn,
      Value<String?> templateKey,
      Value<int> sortOrder,
      Value<bool> archived,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$RoutinesTableReferences
    extends BaseReferences<_$AppDatabase, $RoutinesTable, Routine> {
  $$RoutinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BlocksTable, List<Block>> _blocksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.blocks,
    aliasName: $_aliasNameGenerator(db.routines.id, db.blocks.routineId),
  );

  $$BlocksTableProcessedTableManager get blocksRefs {
    final manager = $$BlocksTableTableManager(
      $_db,
      $_db.blocks,
    ).filter((f) => f.routineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_blocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoutinesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> blocksRefs(
    Expression<bool> Function($$BlocksTableFilterComposer f) f,
  ) {
    final $$BlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableFilterComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> blocksRefs<T extends Object>(
    Expression<T> Function($$BlocksTableAnnotationComposer a) f,
  ) {
    final $$BlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.blocks,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.blocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutinesTable,
          Routine,
          $$RoutinesTableFilterComposer,
          $$RoutinesTableOrderingComposer,
          $$RoutinesTableAnnotationComposer,
          $$RoutinesTableCreateCompanionBuilder,
          $$RoutinesTableUpdateCompanionBuilder,
          (Routine, $$RoutinesTableReferences),
          Routine,
          PrefetchHooks Function({bool blocksRefs})
        > {
  $$RoutinesTableTableManager(_$AppDatabase db, $RoutinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<String?> templateKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutinesCompanion(
                id: id,
                name: name,
                description: description,
                isBuiltIn: isBuiltIn,
                templateKey: templateKey,
                sortOrder: sortOrder,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> description = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<String?> templateKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RoutinesCompanion.insert(
                id: id,
                name: name,
                description: description,
                isBuiltIn: isBuiltIn,
                templateKey: templateKey,
                sortOrder: sortOrder,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoutinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({blocksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (blocksRefs) db.blocks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (blocksRefs)
                    await $_getPrefetchedData<Routine, $RoutinesTable, Block>(
                      currentTable: table,
                      referencedTable: $$RoutinesTableReferences
                          ._blocksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RoutinesTableReferences(db, table, p0).blocksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.routineId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutinesTable,
      Routine,
      $$RoutinesTableFilterComposer,
      $$RoutinesTableOrderingComposer,
      $$RoutinesTableAnnotationComposer,
      $$RoutinesTableCreateCompanionBuilder,
      $$RoutinesTableUpdateCompanionBuilder,
      (Routine, $$RoutinesTableReferences),
      Routine,
      PrefetchHooks Function({bool blocksRefs})
    >;
typedef $$BlocksTableCreateCompanionBuilder =
    BlocksCompanion Function({
      required String id,
      required String routineId,
      required int position,
      required String name,
      Value<String> description,
      required int durationMin,
      required int category,
      Value<bool> trackEnabled,
      Value<int> startMin,
      Value<int> rowid,
    });
typedef $$BlocksTableUpdateCompanionBuilder =
    BlocksCompanion Function({
      Value<String> id,
      Value<String> routineId,
      Value<int> position,
      Value<String> name,
      Value<String> description,
      Value<int> durationMin,
      Value<int> category,
      Value<bool> trackEnabled,
      Value<int> startMin,
      Value<int> rowid,
    });

final class $$BlocksTableReferences
    extends BaseReferences<_$AppDatabase, $BlocksTable, Block> {
  $$BlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoutinesTable _routineIdTable(_$AppDatabase db) => db.routines
      .createAlias($_aliasNameGenerator(db.blocks.routineId, db.routines.id));

  $$RoutinesTableProcessedTableManager get routineId {
    final $_column = $_itemColumn<String>('routine_id')!;

    final manager = $$RoutinesTableTableManager(
      $_db,
      $_db.routines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BlocksTableFilterComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackEnabled => $composableBuilder(
    column: $table.trackEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutinesTableFilterComposer get routineId {
    final $$RoutinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableFilterComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackEnabled => $composableBuilder(
    column: $table.trackEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutinesTableOrderingComposer get routineId {
    final $$RoutinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableOrderingComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlocksTable> {
  $$BlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get trackEnabled => $composableBuilder(
    column: $table.trackEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMin =>
      $composableBuilder(column: $table.startMin, builder: (column) => column);

  $$RoutinesTableAnnotationComposer get routineId {
    final $$RoutinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableAnnotationComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlocksTable,
          Block,
          $$BlocksTableFilterComposer,
          $$BlocksTableOrderingComposer,
          $$BlocksTableAnnotationComposer,
          $$BlocksTableCreateCompanionBuilder,
          $$BlocksTableUpdateCompanionBuilder,
          (Block, $$BlocksTableReferences),
          Block,
          PrefetchHooks Function({bool routineId})
        > {
  $$BlocksTableTableManager(_$AppDatabase db, $BlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routineId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> durationMin = const Value.absent(),
                Value<int> category = const Value.absent(),
                Value<bool> trackEnabled = const Value.absent(),
                Value<int> startMin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion(
                id: id,
                routineId: routineId,
                position: position,
                name: name,
                description: description,
                durationMin: durationMin,
                category: category,
                trackEnabled: trackEnabled,
                startMin: startMin,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routineId,
                required int position,
                required String name,
                Value<String> description = const Value.absent(),
                required int durationMin,
                required int category,
                Value<bool> trackEnabled = const Value.absent(),
                Value<int> startMin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlocksCompanion.insert(
                id: id,
                routineId: routineId,
                position: position,
                name: name,
                description: description,
                durationMin: durationMin,
                category: category,
                trackEnabled: trackEnabled,
                startMin: startMin,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BlocksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({routineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (routineId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.routineId,
                                referencedTable: $$BlocksTableReferences
                                    ._routineIdTable(db),
                                referencedColumn: $$BlocksTableReferences
                                    ._routineIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlocksTable,
      Block,
      $$BlocksTableFilterComposer,
      $$BlocksTableOrderingComposer,
      $$BlocksTableAnnotationComposer,
      $$BlocksTableCreateCompanionBuilder,
      $$BlocksTableUpdateCompanionBuilder,
      (Block, $$BlocksTableReferences),
      Block,
      PrefetchHooks Function({bool routineId})
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required String title,
      Value<String> notes,
      Value<int> priority,
      Value<int?> category,
      Value<DateTime?> dueAt,
      Value<DateTime?> completedAt,
      required DateTime createdAt,
      Value<int> estimatedPomodoros,
      Value<int> completedPomodoros,
      Value<String?> recurrence,
      Value<String?> blockId,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> notes,
      Value<int> priority,
      Value<int?> category,
      Value<DateTime?> dueAt,
      Value<DateTime?> completedAt,
      Value<DateTime> createdAt,
      Value<int> estimatedPomodoros,
      Value<int> completedPomodoros,
      Value<String?> recurrence,
      Value<String?> blockId,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, Task> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SubtasksTable, List<Subtask>> _subtasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.subtasks,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.subtasks.taskId),
  );

  $$SubtasksTableProcessedTableManager get subtasksRefs {
    final manager = $$SubtasksTableTableManager(
      $_db,
      $_db.subtasks,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subtasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskTagsTable, List<TaskTag>> _taskTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTags,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.taskTags.taskId),
  );

  $$TaskTagsTableProcessedTableManager get taskTagsRefs {
    final manager = $$TaskTagsTableTableManager(
      $_db,
      $_db.taskTags,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedPomodoros => $composableBuilder(
    column: $table.estimatedPomodoros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedPomodoros => $composableBuilder(
    column: $table.completedPomodoros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> subtasksRefs(
    Expression<bool> Function($$SubtasksTableFilterComposer f) f,
  ) {
    final $$SubtasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtasksTableFilterComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskTagsRefs(
    Expression<bool> Function($$TaskTagsTableFilterComposer f) f,
  ) {
    final $$TaskTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableFilterComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedPomodoros => $composableBuilder(
    column: $table.estimatedPomodoros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedPomodoros => $composableBuilder(
    column: $table.completedPomodoros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get estimatedPomodoros => $composableBuilder(
    column: $table.estimatedPomodoros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedPomodoros => $composableBuilder(
    column: $table.completedPomodoros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> subtasksRefs<T extends Object>(
    Expression<T> Function($$SubtasksTableAnnotationComposer a) f,
  ) {
    final $$SubtasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtasksTableAnnotationComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskTagsRefs<T extends Object>(
    Expression<T> Function($$TaskTagsTableAnnotationComposer a) f,
  ) {
    final $$TaskTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, $$TasksTableReferences),
          Task,
          PrefetchHooks Function({bool subtasksRefs, bool taskTagsRefs})
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> category = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> estimatedPomodoros = const Value.absent(),
                Value<int> completedPomodoros = const Value.absent(),
                Value<String?> recurrence = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                notes: notes,
                priority: priority,
                category: category,
                dueAt: dueAt,
                completedAt: completedAt,
                createdAt: createdAt,
                estimatedPomodoros: estimatedPomodoros,
                completedPomodoros: completedPomodoros,
                recurrence: recurrence,
                blockId: blockId,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> notes = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> category = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> estimatedPomodoros = const Value.absent(),
                Value<int> completedPomodoros = const Value.absent(),
                Value<String?> recurrence = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                priority: priority,
                category: category,
                dueAt: dueAt,
                completedAt: completedAt,
                createdAt: createdAt,
                estimatedPomodoros: estimatedPomodoros,
                completedPomodoros: completedPomodoros,
                recurrence: recurrence,
                blockId: blockId,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({subtasksRefs = false, taskTagsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (subtasksRefs) db.subtasks,
                    if (taskTagsRefs) db.taskTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (subtasksRefs)
                        await $_getPrefetchedData<Task, $TasksTable, Subtask>(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._subtasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).subtasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskTagsRefs)
                        await $_getPrefetchedData<Task, $TasksTable, TaskTag>(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, $$TasksTableReferences),
      Task,
      PrefetchHooks Function({bool subtasksRefs, bool taskTagsRefs})
    >;
typedef $$SubtasksTableCreateCompanionBuilder =
    SubtasksCompanion Function({
      required String id,
      required String taskId,
      required String title,
      Value<bool> done,
      required int position,
      Value<int> rowid,
    });
typedef $$SubtasksTableUpdateCompanionBuilder =
    SubtasksCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> title,
      Value<bool> done,
      Value<int> position,
      Value<int> rowid,
    });

final class $$SubtasksTableReferences
    extends BaseReferences<_$AppDatabase, $SubtasksTable, Subtask> {
  $$SubtasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.subtasks.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubtasksTableFilterComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubtasksTable,
          Subtask,
          $$SubtasksTableFilterComposer,
          $$SubtasksTableOrderingComposer,
          $$SubtasksTableAnnotationComposer,
          $$SubtasksTableCreateCompanionBuilder,
          $$SubtasksTableUpdateCompanionBuilder,
          (Subtask, $$SubtasksTableReferences),
          Subtask,
          PrefetchHooks Function({bool taskId})
        > {
  $$SubtasksTableTableManager(_$AppDatabase db, $SubtasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion(
                id: id,
                taskId: taskId,
                title: title,
                done: done,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String title,
                Value<bool> done = const Value.absent(),
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion.insert(
                id: id,
                taskId: taskId,
                title: title,
                done: done,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubtasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$SubtasksTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$SubtasksTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubtasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubtasksTable,
      Subtask,
      $$SubtasksTableFilterComposer,
      $$SubtasksTableOrderingComposer,
      $$SubtasksTableAnnotationComposer,
      $$SubtasksTableCreateCompanionBuilder,
      $$SubtasksTableUpdateCompanionBuilder,
      (Subtask, $$SubtasksTableReferences),
      Subtask,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<int> colorIndex,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> colorIndex,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskTagsTable, List<TaskTag>> _taskTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.taskTags.tagId),
  );

  $$TaskTagsTableProcessedTableManager get taskTagsRefs {
    final manager = $$TaskTagsTableTableManager(
      $_db,
      $_db.taskTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskTagsRefs(
    Expression<bool> Function($$TaskTagsTableFilterComposer f) f,
  ) {
    final $$TaskTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableFilterComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  Expression<T> taskTagsRefs<T extends Object>(
    Expression<T> Function($$TaskTagsTableAnnotationComposer a) f,
  ) {
    final $$TaskTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool taskTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                colorIndex: colorIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> colorIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                colorIndex: colorIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({taskTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskTagsRefs) db.taskTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, TaskTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._taskTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).taskTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool taskTagsRefs})
    >;
typedef $$TaskTagsTableCreateCompanionBuilder =
    TaskTagsCompanion Function({
      required String taskId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$TaskTagsTableUpdateCompanionBuilder =
    TaskTagsCompanion Function({
      Value<String> taskId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$TaskTagsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskTagsTable, TaskTag> {
  $$TaskTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.taskTags.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias($_aliasNameGenerator(db.taskTags.tagId, db.tags.id));

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskTagsTable,
          TaskTag,
          $$TaskTagsTableFilterComposer,
          $$TaskTagsTableOrderingComposer,
          $$TaskTagsTableAnnotationComposer,
          $$TaskTagsTableCreateCompanionBuilder,
          $$TaskTagsTableUpdateCompanionBuilder,
          (TaskTag, $$TaskTagsTableReferences),
          TaskTag,
          PrefetchHooks Function({bool taskId, bool tagId})
        > {
  $$TaskTagsTableTableManager(_$AppDatabase db, $TaskTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  TaskTagsCompanion(taskId: taskId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String taskId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion.insert(
                taskId: taskId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$TaskTagsTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$TaskTagsTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$TaskTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$TaskTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskTagsTable,
      TaskTag,
      $$TaskTagsTableFilterComposer,
      $$TaskTagsTableOrderingComposer,
      $$TaskTagsTableAnnotationComposer,
      $$TaskTagsTableCreateCompanionBuilder,
      $$TaskTagsTableUpdateCompanionBuilder,
      (TaskTag, $$TaskTagsTableReferences),
      TaskTag,
      PrefetchHooks Function({bool taskId, bool tagId})
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required DateTime logicalDay,
      Value<String?> routineId,
      Value<String?> blockId,
      Value<String?> taskId,
      required String blockName,
      required int category,
      required int plannedSec,
      Value<int> claimedSec,
      Value<int> verifiedSec,
      required int finalState,
      required int provenance,
      Value<int> factorMask,
      Value<bool> trackEnabled,
      Value<int> violations,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<DateTime> logicalDay,
      Value<String?> routineId,
      Value<String?> blockId,
      Value<String?> taskId,
      Value<String> blockName,
      Value<int> category,
      Value<int> plannedSec,
      Value<int> claimedSec,
      Value<int> verifiedSec,
      Value<int> finalState,
      Value<int> provenance,
      Value<int> factorMask,
      Value<bool> trackEnabled,
      Value<int> violations,
      Value<int> rowid,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionEventsTable, List<SessionEventRow>>
  _sessionEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionEvents,
    aliasName: $_aliasNameGenerator(db.sessions.id, db.sessionEvents.sessionId),
  );

  $$SessionEventsTableProcessedTableManager get sessionEventsRefs {
    final manager = $$SessionEventsTableTableManager(
      $_db,
      $_db.sessionEvents,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get logicalDay => $composableBuilder(
    column: $table.logicalDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockName => $composableBuilder(
    column: $table.blockName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedSec => $composableBuilder(
    column: $table.plannedSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get claimedSec => $composableBuilder(
    column: $table.claimedSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get verifiedSec => $composableBuilder(
    column: $table.verifiedSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finalState => $composableBuilder(
    column: $table.finalState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get factorMask => $composableBuilder(
    column: $table.factorMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackEnabled => $composableBuilder(
    column: $table.trackEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get violations => $composableBuilder(
    column: $table.violations,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionEventsRefs(
    Expression<bool> Function($$SessionEventsTableFilterComposer f) f,
  ) {
    final $$SessionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionEventsTableFilterComposer(
            $db: $db,
            $table: $db.sessionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get logicalDay => $composableBuilder(
    column: $table.logicalDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockName => $composableBuilder(
    column: $table.blockName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedSec => $composableBuilder(
    column: $table.plannedSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get claimedSec => $composableBuilder(
    column: $table.claimedSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get verifiedSec => $composableBuilder(
    column: $table.verifiedSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finalState => $composableBuilder(
    column: $table.finalState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get factorMask => $composableBuilder(
    column: $table.factorMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackEnabled => $composableBuilder(
    column: $table.trackEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get violations => $composableBuilder(
    column: $table.violations,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get logicalDay => $composableBuilder(
    column: $table.logicalDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get blockName =>
      $composableBuilder(column: $table.blockName, builder: (column) => column);

  GeneratedColumn<int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get plannedSec => $composableBuilder(
    column: $table.plannedSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get claimedSec => $composableBuilder(
    column: $table.claimedSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get verifiedSec => $composableBuilder(
    column: $table.verifiedSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get finalState => $composableBuilder(
    column: $table.finalState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get factorMask => $composableBuilder(
    column: $table.factorMask,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trackEnabled => $composableBuilder(
    column: $table.trackEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get violations => $composableBuilder(
    column: $table.violations,
    builder: (column) => column,
  );

  Expression<T> sessionEventsRefs<T extends Object>(
    Expression<T> Function($$SessionEventsTableAnnotationComposer a) f,
  ) {
    final $$SessionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool sessionEventsRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<DateTime> logicalDay = const Value.absent(),
                Value<String?> routineId = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String> blockName = const Value.absent(),
                Value<int> category = const Value.absent(),
                Value<int> plannedSec = const Value.absent(),
                Value<int> claimedSec = const Value.absent(),
                Value<int> verifiedSec = const Value.absent(),
                Value<int> finalState = const Value.absent(),
                Value<int> provenance = const Value.absent(),
                Value<int> factorMask = const Value.absent(),
                Value<bool> trackEnabled = const Value.absent(),
                Value<int> violations = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                logicalDay: logicalDay,
                routineId: routineId,
                blockId: blockId,
                taskId: taskId,
                blockName: blockName,
                category: category,
                plannedSec: plannedSec,
                claimedSec: claimedSec,
                verifiedSec: verifiedSec,
                finalState: finalState,
                provenance: provenance,
                factorMask: factorMask,
                trackEnabled: trackEnabled,
                violations: violations,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required DateTime logicalDay,
                Value<String?> routineId = const Value.absent(),
                Value<String?> blockId = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                required String blockName,
                required int category,
                required int plannedSec,
                Value<int> claimedSec = const Value.absent(),
                Value<int> verifiedSec = const Value.absent(),
                required int finalState,
                required int provenance,
                Value<int> factorMask = const Value.absent(),
                Value<bool> trackEnabled = const Value.absent(),
                Value<int> violations = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                logicalDay: logicalDay,
                routineId: routineId,
                blockId: blockId,
                taskId: taskId,
                blockName: blockName,
                category: category,
                plannedSec: plannedSec,
                claimedSec: claimedSec,
                verifiedSec: verifiedSec,
                finalState: finalState,
                provenance: provenance,
                factorMask: factorMask,
                trackEnabled: trackEnabled,
                violations: violations,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionEventsRefs) db.sessionEvents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionEventsRefs)
                    await $_getPrefetchedData<
                      Session,
                      $SessionsTable,
                      SessionEventRow
                    >(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences
                          ._sessionEventsRefsTable(db),
                      managerFromTypedResult: (p0) => $$SessionsTableReferences(
                        db,
                        table,
                        p0,
                      ).sessionEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool sessionEventsRefs})
    >;
typedef $$SessionEventsTableCreateCompanionBuilder =
    SessionEventsCompanion Function({
      required String id,
      required String sessionId,
      required DateTime at,
      required int kind,
      Value<int?> fromState,
      Value<int?> toState,
      Value<int?> reason,
      Value<int> factorMask,
      Value<String> detail,
      Value<int> rowid,
    });
typedef $$SessionEventsTableUpdateCompanionBuilder =
    SessionEventsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<DateTime> at,
      Value<int> kind,
      Value<int?> fromState,
      Value<int?> toState,
      Value<int?> reason,
      Value<int> factorMask,
      Value<String> detail,
      Value<int> rowid,
    });

final class $$SessionEventsTableReferences
    extends
        BaseReferences<_$AppDatabase, $SessionEventsTable, SessionEventRow> {
  $$SessionEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias(
        $_aliasNameGenerator(db.sessionEvents.sessionId, db.sessions.id),
      );

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionEventsTable> {
  $$SessionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fromState => $composableBuilder(
    column: $table.fromState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toState => $composableBuilder(
    column: $table.toState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get factorMask => $composableBuilder(
    column: $table.factorMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionEventsTable> {
  $$SessionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fromState => $composableBuilder(
    column: $table.fromState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toState => $composableBuilder(
    column: $table.toState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get factorMask => $composableBuilder(
    column: $table.factorMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionEventsTable> {
  $$SessionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get fromState =>
      $composableBuilder(column: $table.fromState, builder: (column) => column);

  GeneratedColumn<int> get toState =>
      $composableBuilder(column: $table.toState, builder: (column) => column);

  GeneratedColumn<int> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get factorMask => $composableBuilder(
    column: $table.factorMask,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionEventsTable,
          SessionEventRow,
          $$SessionEventsTableFilterComposer,
          $$SessionEventsTableOrderingComposer,
          $$SessionEventsTableAnnotationComposer,
          $$SessionEventsTableCreateCompanionBuilder,
          $$SessionEventsTableUpdateCompanionBuilder,
          (SessionEventRow, $$SessionEventsTableReferences),
          SessionEventRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SessionEventsTableTableManager(_$AppDatabase db, $SessionEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<int?> fromState = const Value.absent(),
                Value<int?> toState = const Value.absent(),
                Value<int?> reason = const Value.absent(),
                Value<int> factorMask = const Value.absent(),
                Value<String> detail = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionEventsCompanion(
                id: id,
                sessionId: sessionId,
                at: at,
                kind: kind,
                fromState: fromState,
                toState: toState,
                reason: reason,
                factorMask: factorMask,
                detail: detail,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required DateTime at,
                required int kind,
                Value<int?> fromState = const Value.absent(),
                Value<int?> toState = const Value.absent(),
                Value<int?> reason = const Value.absent(),
                Value<int> factorMask = const Value.absent(),
                Value<String> detail = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                at: at,
                kind: kind,
                fromState: fromState,
                toState: toState,
                reason: reason,
                factorMask: factorMask,
                detail: detail,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$SessionEventsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$SessionEventsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionEventsTable,
      SessionEventRow,
      $$SessionEventsTableFilterComposer,
      $$SessionEventsTableOrderingComposer,
      $$SessionEventsTableAnnotationComposer,
      $$SessionEventsTableCreateCompanionBuilder,
      $$SessionEventsTableUpdateCompanionBuilder,
      (SessionEventRow, $$SessionEventsTableReferences),
      SessionEventRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$DayLogsTableCreateCompanionBuilder =
    DayLogsCompanion Function({
      required DateTime day,
      Value<int> verifiedMin,
      Value<int> claimedMin,
      Value<int> blocksDone,
      Value<int> blocksTotal,
      Value<int> violations,
      Value<int> source,
      Value<int> rowid,
    });
typedef $$DayLogsTableUpdateCompanionBuilder =
    DayLogsCompanion Function({
      Value<DateTime> day,
      Value<int> verifiedMin,
      Value<int> claimedMin,
      Value<int> blocksDone,
      Value<int> blocksTotal,
      Value<int> violations,
      Value<int> source,
      Value<int> rowid,
    });

class $$DayLogsTableFilterComposer
    extends Composer<_$AppDatabase, $DayLogsTable> {
  $$DayLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get verifiedMin => $composableBuilder(
    column: $table.verifiedMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get claimedMin => $composableBuilder(
    column: $table.claimedMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blocksDone => $composableBuilder(
    column: $table.blocksDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blocksTotal => $composableBuilder(
    column: $table.blocksTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get violations => $composableBuilder(
    column: $table.violations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DayLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $DayLogsTable> {
  $$DayLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get verifiedMin => $composableBuilder(
    column: $table.verifiedMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get claimedMin => $composableBuilder(
    column: $table.claimedMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blocksDone => $composableBuilder(
    column: $table.blocksDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blocksTotal => $composableBuilder(
    column: $table.blocksTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get violations => $composableBuilder(
    column: $table.violations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DayLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayLogsTable> {
  $$DayLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get verifiedMin => $composableBuilder(
    column: $table.verifiedMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get claimedMin => $composableBuilder(
    column: $table.claimedMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blocksDone => $composableBuilder(
    column: $table.blocksDone,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blocksTotal => $composableBuilder(
    column: $table.blocksTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get violations => $composableBuilder(
    column: $table.violations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$DayLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayLogsTable,
          DayLog,
          $$DayLogsTableFilterComposer,
          $$DayLogsTableOrderingComposer,
          $$DayLogsTableAnnotationComposer,
          $$DayLogsTableCreateCompanionBuilder,
          $$DayLogsTableUpdateCompanionBuilder,
          (DayLog, BaseReferences<_$AppDatabase, $DayLogsTable, DayLog>),
          DayLog,
          PrefetchHooks Function()
        > {
  $$DayLogsTableTableManager(_$AppDatabase db, $DayLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> day = const Value.absent(),
                Value<int> verifiedMin = const Value.absent(),
                Value<int> claimedMin = const Value.absent(),
                Value<int> blocksDone = const Value.absent(),
                Value<int> blocksTotal = const Value.absent(),
                Value<int> violations = const Value.absent(),
                Value<int> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayLogsCompanion(
                day: day,
                verifiedMin: verifiedMin,
                claimedMin: claimedMin,
                blocksDone: blocksDone,
                blocksTotal: blocksTotal,
                violations: violations,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime day,
                Value<int> verifiedMin = const Value.absent(),
                Value<int> claimedMin = const Value.absent(),
                Value<int> blocksDone = const Value.absent(),
                Value<int> blocksTotal = const Value.absent(),
                Value<int> violations = const Value.absent(),
                Value<int> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayLogsCompanion.insert(
                day: day,
                verifiedMin: verifiedMin,
                claimedMin: claimedMin,
                blocksDone: blocksDone,
                blocksTotal: blocksTotal,
                violations: violations,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DayLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayLogsTable,
      DayLog,
      $$DayLogsTableFilterComposer,
      $$DayLogsTableOrderingComposer,
      $$DayLogsTableAnnotationComposer,
      $$DayLogsTableCreateCompanionBuilder,
      $$DayLogsTableUpdateCompanionBuilder,
      (DayLog, BaseReferences<_$AppDatabase, $DayLogsTable, DayLog>),
      DayLog,
      PrefetchHooks Function()
    >;
typedef $$DeviceProfilesTableCreateCompanionBuilder =
    DeviceProfilesCompanion Function({
      required String address,
      required String name,
      Value<int> protoVersion,
      Value<int> fwMajor,
      Value<int> fwMinor,
      Value<int> deviceId,
      Value<int> capsLo,
      Value<int> capsHi,
      Value<int> eepromLogDays,
      Value<int> maxBlocks,
      Value<DateTime?> lastSeenAt,
      Value<bool> autoConnect,
      Value<int> rowid,
    });
typedef $$DeviceProfilesTableUpdateCompanionBuilder =
    DeviceProfilesCompanion Function({
      Value<String> address,
      Value<String> name,
      Value<int> protoVersion,
      Value<int> fwMajor,
      Value<int> fwMinor,
      Value<int> deviceId,
      Value<int> capsLo,
      Value<int> capsHi,
      Value<int> eepromLogDays,
      Value<int> maxBlocks,
      Value<DateTime?> lastSeenAt,
      Value<bool> autoConnect,
      Value<int> rowid,
    });

class $$DeviceProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceProfilesTable> {
  $$DeviceProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protoVersion => $composableBuilder(
    column: $table.protoVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fwMajor => $composableBuilder(
    column: $table.fwMajor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fwMinor => $composableBuilder(
    column: $table.fwMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capsLo => $composableBuilder(
    column: $table.capsLo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capsHi => $composableBuilder(
    column: $table.capsHi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eepromLogDays => $composableBuilder(
    column: $table.eepromLogDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxBlocks => $composableBuilder(
    column: $table.maxBlocks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceProfilesTable> {
  $$DeviceProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protoVersion => $composableBuilder(
    column: $table.protoVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fwMajor => $composableBuilder(
    column: $table.fwMajor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fwMinor => $composableBuilder(
    column: $table.fwMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capsLo => $composableBuilder(
    column: $table.capsLo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capsHi => $composableBuilder(
    column: $table.capsHi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eepromLogDays => $composableBuilder(
    column: $table.eepromLogDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxBlocks => $composableBuilder(
    column: $table.maxBlocks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceProfilesTable> {
  $$DeviceProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get protoVersion => $composableBuilder(
    column: $table.protoVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fwMajor =>
      $composableBuilder(column: $table.fwMajor, builder: (column) => column);

  GeneratedColumn<int> get fwMinor =>
      $composableBuilder(column: $table.fwMinor, builder: (column) => column);

  GeneratedColumn<int> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get capsLo =>
      $composableBuilder(column: $table.capsLo, builder: (column) => column);

  GeneratedColumn<int> get capsHi =>
      $composableBuilder(column: $table.capsHi, builder: (column) => column);

  GeneratedColumn<int> get eepromLogDays => $composableBuilder(
    column: $table.eepromLogDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxBlocks =>
      $composableBuilder(column: $table.maxBlocks, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoConnect => $composableBuilder(
    column: $table.autoConnect,
    builder: (column) => column,
  );
}

class $$DeviceProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceProfilesTable,
          DeviceProfile,
          $$DeviceProfilesTableFilterComposer,
          $$DeviceProfilesTableOrderingComposer,
          $$DeviceProfilesTableAnnotationComposer,
          $$DeviceProfilesTableCreateCompanionBuilder,
          $$DeviceProfilesTableUpdateCompanionBuilder,
          (
            DeviceProfile,
            BaseReferences<_$AppDatabase, $DeviceProfilesTable, DeviceProfile>,
          ),
          DeviceProfile,
          PrefetchHooks Function()
        > {
  $$DeviceProfilesTableTableManager(
    _$AppDatabase db,
    $DeviceProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> address = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> protoVersion = const Value.absent(),
                Value<int> fwMajor = const Value.absent(),
                Value<int> fwMinor = const Value.absent(),
                Value<int> deviceId = const Value.absent(),
                Value<int> capsLo = const Value.absent(),
                Value<int> capsHi = const Value.absent(),
                Value<int> eepromLogDays = const Value.absent(),
                Value<int> maxBlocks = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<bool> autoConnect = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceProfilesCompanion(
                address: address,
                name: name,
                protoVersion: protoVersion,
                fwMajor: fwMajor,
                fwMinor: fwMinor,
                deviceId: deviceId,
                capsLo: capsLo,
                capsHi: capsHi,
                eepromLogDays: eepromLogDays,
                maxBlocks: maxBlocks,
                lastSeenAt: lastSeenAt,
                autoConnect: autoConnect,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String address,
                required String name,
                Value<int> protoVersion = const Value.absent(),
                Value<int> fwMajor = const Value.absent(),
                Value<int> fwMinor = const Value.absent(),
                Value<int> deviceId = const Value.absent(),
                Value<int> capsLo = const Value.absent(),
                Value<int> capsHi = const Value.absent(),
                Value<int> eepromLogDays = const Value.absent(),
                Value<int> maxBlocks = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<bool> autoConnect = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceProfilesCompanion.insert(
                address: address,
                name: name,
                protoVersion: protoVersion,
                fwMajor: fwMajor,
                fwMinor: fwMinor,
                deviceId: deviceId,
                capsLo: capsLo,
                capsHi: capsHi,
                eepromLogDays: eepromLogDays,
                maxBlocks: maxBlocks,
                lastSeenAt: lastSeenAt,
                autoConnect: autoConnect,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceProfilesTable,
      DeviceProfile,
      $$DeviceProfilesTableFilterComposer,
      $$DeviceProfilesTableOrderingComposer,
      $$DeviceProfilesTableAnnotationComposer,
      $$DeviceProfilesTableCreateCompanionBuilder,
      $$DeviceProfilesTableUpdateCompanionBuilder,
      (
        DeviceProfile,
        BaseReferences<_$AppDatabase, $DeviceProfilesTable, DeviceProfile>,
      ),
      DeviceProfile,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$AchievementsTableCreateCompanionBuilder =
    AchievementsCompanion Function({
      required String key,
      Value<int> progress,
      Value<DateTime?> unlockedAt,
      Value<int> rowid,
    });
typedef $$AchievementsTableUpdateCompanionBuilder =
    AchievementsCompanion Function({
      Value<String> key,
      Value<int> progress,
      Value<DateTime?> unlockedAt,
      Value<int> rowid,
    });

class $$AchievementsTableFilterComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AchievementsTableOrderingComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AchievementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => column,
  );
}

class $$AchievementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AchievementsTable,
          AchievementRow,
          $$AchievementsTableFilterComposer,
          $$AchievementsTableOrderingComposer,
          $$AchievementsTableAnnotationComposer,
          $$AchievementsTableCreateCompanionBuilder,
          $$AchievementsTableUpdateCompanionBuilder,
          (
            AchievementRow,
            BaseReferences<_$AppDatabase, $AchievementsTable, AchievementRow>,
          ),
          AchievementRow,
          PrefetchHooks Function()
        > {
  $$AchievementsTableTableManager(_$AppDatabase db, $AchievementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AchievementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AchievementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AchievementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<DateTime?> unlockedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AchievementsCompanion(
                key: key,
                progress: progress,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<int> progress = const Value.absent(),
                Value<DateTime?> unlockedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AchievementsCompanion.insert(
                key: key,
                progress: progress,
                unlockedAt: unlockedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AchievementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AchievementsTable,
      AchievementRow,
      $$AchievementsTableFilterComposer,
      $$AchievementsTableOrderingComposer,
      $$AchievementsTableAnnotationComposer,
      $$AchievementsTableCreateCompanionBuilder,
      $$AchievementsTableUpdateCompanionBuilder,
      (
        AchievementRow,
        BaseReferences<_$AppDatabase, $AchievementsTable, AchievementRow>,
      ),
      AchievementRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RoutinesTableTableManager get routines =>
      $$RoutinesTableTableManager(_db, _db.routines);
  $$BlocksTableTableManager get blocks =>
      $$BlocksTableTableManager(_db, _db.blocks);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db, _db.subtasks);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TaskTagsTableTableManager get taskTags =>
      $$TaskTagsTableTableManager(_db, _db.taskTags);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionEventsTableTableManager get sessionEvents =>
      $$SessionEventsTableTableManager(_db, _db.sessionEvents);
  $$DayLogsTableTableManager get dayLogs =>
      $$DayLogsTableTableManager(_db, _db.dayLogs);
  $$DeviceProfilesTableTableManager get deviceProfiles =>
      $$DeviceProfilesTableTableManager(_db, _db.deviceProfiles);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$AchievementsTableTableManager get achievements =>
      $$AchievementsTableTableManager(_db, _db.achievements);
}
