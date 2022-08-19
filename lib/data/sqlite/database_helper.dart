import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlbrite/sqlbrite.dart';
import 'package:synchronized/synchronized.dart';

import '../models/models.dart';
import '../models/workout_exercise.dart';

part 'migrations.dart';

String kLocale = Intl.getCurrentLocale();

class DatabaseHelper {
  static const _databaseName = 'npng.db';
  static const _databaseVersion = 3;

  static const String muscleTable = 'muscles';
  static const String exerciseTable = 'exercises';
  static const String programsTable = 'programs';
  static const String exercisesMusclesTable = 'exercises_muscles';
  static const String userTable = 'user';
  static const String daysTable = 'days';
  static const String workoutsTable = 'workouts';
  static const String logDaysTable = 'log_days';
  static const String logWorkoutsTable = 'log_ex';
  static const String equipmentTable = 'equipment';

  static late BriteDatabase _streamDatabase;

  // make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static var lock = Lock();

  // only have a single app-wide reference to the database
  static Database? _database;

  /// Open the database or create it from asset.
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);
    // final bool exists = await databaseExists(path);

    // Extract db from asset if it doesn't exist
    // if (!exists) {
    //   try {
    //     await Directory(dirname(path)).create(recursive: true);
    //   } catch (_) {}
    //   ByteData data = await rootBundle.load(join('assets/db', 'npng.db'));
    //   List<int> bytes =
    //       data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    //   await File(path).writeAsBytes(bytes, flush: true);
    // }

    // Sqlite debug mode/logging
    if (kDebugMode) {
      Sqflite.setDebugModeOn(true);
    } else {
      Sqflite.setDebugModeOn(false);
    }

    Database db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        // ! Here always created a new database from an asset with the current version.
        // ! If you want to upgrade the database, first you need to do it
        // ! manually in assets/db/npng.db then create the migration.
        // ! After modifying the database, you need to update the version number in the PRAGMA user_version = 5
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (_) {}
        ByteData data = await rootBundle.load(join('assets/db', 'npng.db'));
        List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (kDebugMode) {
          print('→ oldVersion: $oldVersion');
          print('→ newVersion: $newVersion');
        }
        // If database exists, migrate it
        //if (exists) {
        Batch batch = db.batch();
        if (oldVersion == 1) {
          _upgradeV1toV2(batch);
          if (kDebugMode) {
            print('→ Database migrated from v1 to v2.');
          }
        }
        if (oldVersion == 2) {
          _updateV2toV3(batch);
          if (kDebugMode) {
            print('→ Database migrated from v2 to v3.');
          }
        }
        await batch.commit();
        //}
      },
    );

    return db;
  }

  /// Stream database getter.
  Future<Database> get database async {
    if (_database != null) return _database!;
    // Use this object to prevent concurrent access to data
    await lock.synchronized(() async {
      // lazily instantiate the db the first time it is accessed
      if (_database == null) {
        _database = await _initDatabase();
        _streamDatabase = BriteDatabase(_database!);
      }
    });
    return _database!;
  }

  Future<BriteDatabase> get streamDatabase async {
    await database;
    return _streamDatabase;
  }

  /// Backup
  Future<String> backupDatabase() async {
    final db = await instance.streamDatabase;
    String path = '${await getDatabasesPath()}/npng-backup.db';
    try {
      await deleteDbBackupFile(path);
      await db.rawQuery("VACUUM INTO '$path'");
      return path;
    } catch (e) {
      return '';
    }
  }

  /// Delete backup file.
  Future<void> deleteDbBackupFile(String filePath) async {
    if (filePath != '${await getDatabasesPath()}/npng.db') {
      File fileToDel = File(filePath);
      if (await fileToDel.exists()) {
        fileToDel.delete();
      }
    }
  }

  /// Import DB.
  Future<void> importDataBase(String filePath) async {
    final db = await instance.streamDatabase;
    File file = File(filePath);
    String pathToDb = '${await getDatabasesPath()}/npng.db';
    await db.close();
    _database = null;
    file.copySync(pathToDb);
    return Future.value();
  }

  // Muscles

  /// Get all muscles.
  Stream<List<Muscle>> watchAllMuscles() async* {
    final db = await instance.streamDatabase;
    yield* db.createQuery(
      muscleTable,
      columns: [
        'id',
        '${kLocale}_name as name',
        'icon',
      ],
    ).mapToList((row) => Muscle.fromJson(row));
  }

  /// Get all programs.
  Stream<List<Program>> watchAllPrograms() async* {
    final db = await instance.streamDatabase;
    yield* db.createQuery(
      programsTable,
      columns: [
        'id',
        '${kLocale}_name as name',
        '${kLocale}_description as description',
      ],
    ).mapToList((row) => Program.fromJson(row));
  }

  Stream<List<Exercise>> findExcersisesByMuscle(int id) async* {
    final db = await instance.streamDatabase;
    String sql =
        '''SELECT exercises.id AS id, exercises.${kLocale}_name AS name, 
           ${kLocale}_description AS description, equipment_id
           FROM $exercisesMusclesTable  
           JOIN $exerciseTable ON exercises_id = exercises.id 
           WHERE muscles_id = $id''';

    yield* db.createRawQuery([exercisesMusclesTable], sql).mapToList(
        (row) => Exercise.fromJson(row));
  }

  Future<Exercise> findExerciseById(id) async {
    final db = await instance.streamDatabase;
    final exeList = await db.query(
      exerciseTable,
      columns: [
        'id',
        '${kLocale}_name as name',
        '${kLocale}_description as description',
      ],
      where: 'id = $id',
      limit: 1,
    );
    final Exercise exe = Exercise.fromJson(exeList.first);
    return exe;
  }

  Future<int> updateExercise(Exercise exe) async {
    final db = await instance.streamDatabase;
    return db.rawUpdate(
        'UPDATE $exerciseTable SET ${kLocale}_name = ?, ${kLocale}_description = ? WHERE id = ${exe.id}',
        [exe.name, exe.description, exe.id]);
  }

  Future<void> insertExercise(int muscleId, Exercise exercise) async {
    final db = await instance.streamDatabase;
    await db.transaction((txn) async {
      int id = await txn.insert(exerciseTable, {
        '${kLocale}_name': exercise.name,
        '${kLocale}_description': exercise.description,
      });
      await txn.insert(exercisesMusclesTable, {
        'exercises_id': id,
        'muscles_id': muscleId,
      });
    });
    return Future.value();
  }

  Future<void> deleteExercise(Exercise exercise) async {
    final db = await instance.streamDatabase;
    await db.transaction((txn) async {
      await txn
          .delete(exerciseTable, where: 'id = ?', whereArgs: [exercise.id]);
      await txn.delete(exercisesMusclesTable,
          where: 'exercises_id = ?', whereArgs: [exercise.id]);
    });
    return Future.value();
  }

  Future<int> getCurrentProgram() async {
    final db = await instance.streamDatabase;
    final userList = await db.query(userTable, where: 'id = 1');
    return userList.first['programs_id'] as int;
  }

  Future<void> setCurrentProgram(int id) async {
    final db = await instance.streamDatabase;
    await db.update(userTable, {'programs_id': id}, where: 'id = 1');
    return Future.value();
  }

  Future<void> insertProgram(Exercise program) async {
    final db = await instance.streamDatabase;
    await db.insert(programsTable, {
      '${kLocale}_name': program.name,
      '${kLocale}_description': program.description,
    });
    return Future.value();
  }

  Future<int> updateProgram(Program program) async {
    final db = await instance.streamDatabase;
    return db.rawUpdate(
        'UPDATE $programsTable SET ${kLocale}_name = ?, ${kLocale}_description = ? WHERE id = ?',
        [program.name, program.description, program.id]);
  }

  // Days

  Stream<List<Day>> findDaysByProgram(int id) async* {
    final db = await instance.streamDatabase;

    yield* db
        .createQuery(daysTable,
            columns: [
              'id',
              'ord',
              '${kLocale}_name AS name',
              '${kLocale}_description AS description',
              'programs_id',
            ],
            orderBy: 'ord',
            where: 'programs_id = ?',
            whereArgs: [id])
        .mapToList((row) => Day.fromJson(row));
  }

  Future<void> reorderDays(List<Day> days) async {
    final db = await instance.streamDatabase;
    await db.transaction((txn) async {
      for (int i = 0; i <= days.length - 1; i++) {
        await txn.update(
          daysTable,
          {'ord': i},
          where: 'id = ?',
          whereArgs: [days[i].id],
        );
      }
    });
    return Future.value();
  }

  Future<void> insertDay(int programId, Day day) async {
    final db = await instance.streamDatabase;

    final queryResult = await db.query(
      daysTable,
      columns: ['MAX(ord) AS maxOrd'],
      where: 'programs_id = ?',
      whereArgs: [programId],
    );
    int maxOrd = (queryResult.first['maxOrd'] != null)
        ? queryResult.first['maxOrd'] as int
        : -1;

    await db.insert(daysTable, {
      '${kLocale}_name': day.name,
      'ord': ++maxOrd,
      '${kLocale}_description': day.description,
      'programs_id': programId,
    });
    return Future.value();
  }

  Future<int> updateDay(Day day) async {
    final db = await instance.streamDatabase;
    return db.rawUpdate(
        'UPDATE $daysTable SET ${kLocale}_name = ?, ${kLocale}_description = ? WHERE id = ?',
        [day.name, day.description, day.id]);
  }

  // Workouts

  /// Return workout as a stream.
  Stream<List<Workout>> findWorkoutByDay(int dayId) async* {
    final db = await instance.streamDatabase;
    final String sql = '''
    SELECT 
      workouts.id AS id, 
      exercises.${kLocale}_name AS name, 
      exercises.${kLocale}_description as description, 
      sets, ord, repeats, rest, exercises_id, weight FROM workouts 
    JOIN exercises on workouts.exercises_id = exercises.id 
    WHERE days_id = $dayId ORDER BY ord;
      ''';
    yield* db.createRawQuery(
        [workoutsTable], sql).mapToList((row) => Workout.fromJson(row));
  }

  Future<void> reorderWorkouts(List<Workout> workouts) async {
    final db = await instance.streamDatabase;
    await db.transaction((txn) async {
      for (int i = 0; i <= workouts.length - 1; i++) {
        await txn.update(
          workoutsTable,
          {'ord': i},
          where: 'id = ?',
          whereArgs: [workouts[i].id],
        );
      }
    });
    return Future.value();
  }

  Future<void> updateWorkoutSetsRepeatsRest(Workout workout) async {
    final db = await instance.streamDatabase;
    await db.update(
      workoutsTable,
      {
        'sets': workout.sets,
        'repeats': workout.repeats,
        'rest': workout.rest,
      },
      where: 'id = ?',
      whereArgs: [workout.id],
    );
    return Future.value();
  }

  Future<void> deleteWorkout(Workout workout) async {
    final db = await instance.streamDatabase;
    await db.delete(
      workoutsTable,
      where: 'id = ?',
      whereArgs: [workout.id],
    );
    return Future.value();
  }

  Future<void> insertWorkout(int dayId, int exersiseId) async {
    final db = await instance.streamDatabase;
    final queryResult = await db.query(
      workoutsTable,
      columns: ['MAX(ord) AS maxOrd'],
      where: 'days_id = ?',
      whereArgs: [dayId],
    );
    int maxOrd = (queryResult.first['maxOrd'] != null)
        ? queryResult.first['maxOrd'] as int
        : -1;

    await db.insert(
      workoutsTable,
      {
        'ord': ++maxOrd,
        'exercises_id': exersiseId,
        'days_id': dayId,
      },
    );
    return Future.value();
  }

  // Equipment

  /// Watch all equipment.
  /// Return equipment as a stream.
  Stream<List<Equipment>> watchAllEquipment() async* {
    final db = await instance.streamDatabase;
    yield* db.createQuery(
      equipmentTable,
      columns: [
        'id',
        '${kLocale}_name AS name',
        'preinstalled',
      ],
    ).mapToList((row) => Equipment.fromJson(row));
  }

  // Log

  /// All log days.
  Future<List<LogDay>> wathchAllLogDays() async {
    final db = await instance.streamDatabase;
    final String sql = '''
    select 
      $logDaysTable.id AS logDaysId, 
      $logDaysTable.days_id AS daysId, 
      start, 
      finish,
      $daysTable.${kLocale}_name AS daysName,
      $programsTable.${kLocale}_name as programsName
    from $logDaysTable
    join $daysTable on $logDaysTable.days_id = $daysTable.id 
    join $programsTable on $daysTable.programs_id = $programsTable.id
    ORDER BY logDaysId
    ''';
    final List<Map<String, dynamic>> list = await db.rawQuery(sql);
    List<LogDay> result = [];
    for (Map<String, dynamic> item in list) {
      result.add(LogDay.fromJson(item));
    }
    return result;
  }

  /// Get workout for day in log.
  Future<List<LogWorkout>> findLogWorkoutByDay(int logDayId) async {
    final db = await instance.streamDatabase;
    final String sql = '''
    SELECT $logWorkoutsTable.exercises_id AS id,
              repeat,
              weight,
              $exerciseTable.${kLocale}_name AS name
        FROM $logWorkoutsTable
              JOIN
              $exerciseTable ON $logWorkoutsTable.exercises_id = $exerciseTable.id
        WHERE $logWorkoutsTable.log_days_id = $logDayId
        ORDER BY $logWorkoutsTable.id;
    ''';
    final List<Map<String, dynamic>> list = await db.rawQuery(sql);
    List<LogWorkout> result = [];
    for (Map<String, dynamic> item in list) {
      result.add(LogWorkout.fromJson(item));
    }
    return result;
  }

  Future<void> insertLog({
    required DateTime startTime,
    required DateTime finishTime,
    required int dayId,
    required List<WorkoutExercise> exercises,
  }) async {
    final db = await instance.streamDatabase;

    int logDaysId = await db.insert(logDaysTable, {
      'start': startTime.toLocal().toString(),
      'finish': finishTime.toLocal().toString(),
      'days_id': dayId,
    });

    await db.transaction((txn) async {
      for (WorkoutExercise item in exercises) {
        for (int i = 0; i < item.sets.length; i++) {
          await txn.insert(logWorkoutsTable, {
            'log_days_id': logDaysId,
            'exercises_id': item.id,
            'repeat': item.sets[i].repeats,
            'weight': item.sets[i].weight,
          });
        }
      }
    });

    return Future.value();
  }

  void close() {
    _streamDatabase.close();
  }
}
