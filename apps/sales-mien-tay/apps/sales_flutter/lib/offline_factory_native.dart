import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
IdbFactory offlineFactory()=>getIdbFactorySqflite(sqlite.databaseFactory);
