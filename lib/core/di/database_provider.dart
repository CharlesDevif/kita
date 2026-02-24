import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/database_config.dart';
import '../data/database.dart';
import '../utils/logger.dart';

part 'database_provider.g.dart';

final _log = KitaLogger('Database');

@Riverpod(keepAlive: true)
Future<KitaDatabase> kitaDatabase(Ref ref) async {
  final encryptionKey = await DatabaseConfig.getOrCreateEncryptionKey();
  final dbFile = await DatabaseConfig.getDatabaseFile();

  final executor = DatabaseConfig.openEncryptedDatabase(dbFile, encryptionKey);
  _log.info('Opening encrypted database');

  final database = KitaDatabase(executor);

  ref.onDispose(() {
    database.close();
    _log.info('Database closed');
  });

  return database;
}
