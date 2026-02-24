import 'package:drift/drift.dart';

part 'database.g.dart';

@DriftDatabase(
  include: {
    '../../features/ai/data/tables/request_cache.drift',
    '../../features/memory/data/tables/episodes.drift',
    '../../features/memory/data/tables/preferences.drift',
    '../../features/memory/data/tables/persons.drift',
    '../../features/memory/data/tables/user_profiles.drift',
    '../../features/memory/data/tables/consent_log.drift',
    '../../features/plugins/data/tables/plugin_data.drift',
  },
)
class KitaDatabase extends _$KitaDatabase {
  KitaDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
