import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../core/network/network_state.dart';
import '../core/network/api_client.dart';
import '../core/network/embedded_server.dart';
import '../repositories/concurso_repository.dart';
import '../repositories/artesano_repository.dart';
import '../repositories/registro_repository.dart';
import '../repositories/premio_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final apiClientProvider = Provider<ApiClient?>((ref) {
  final config = ref.watch(networkConfigProvider);
  if (config.isClient) {
    return ApiClient(baseUrl: config.clientBaseUrl);
  }
  return null;
});

final embeddedServerProvider = Provider<EmbeddedServer>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EmbeddedServer(
    concursoRepo: ConcursoRepository(dbHelper: db),
    artesanoRepo: ArtesanoRepository(dbHelper: db),
    registroRepo: RegistroRepository(dbHelper: db),
    premioRepo: PremioRepository(dbHelper: db),
  );
});

final concursoRepositoryProvider = Provider<ConcursoRepository>((ref) {
  final config = ref.watch(networkConfigProvider);
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isClient && apiClient != null) {
    return ConcursoRepository(apiClient: apiClient);
  }
  return ConcursoRepository(dbHelper: db);
});

final artesanoRepositoryProvider = Provider<ArtesanoRepository>((ref) {
  final config = ref.watch(networkConfigProvider);
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isClient && apiClient != null) {
    return ArtesanoRepository(apiClient: apiClient);
  }
  return ArtesanoRepository(dbHelper: db);
});

final registroRepositoryProvider = Provider<RegistroRepository>((ref) {
  final config = ref.watch(networkConfigProvider);
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isClient && apiClient != null) {
    return RegistroRepository(apiClient: apiClient);
  }
  return RegistroRepository(dbHelper: db);
});

final premioRepositoryProvider = Provider<PremioRepository>((ref) {
  final config = ref.watch(networkConfigProvider);
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);

  if (config.isClient && apiClient != null) {
    return PremioRepository(apiClient: apiClient);
  }
  return PremioRepository(dbHelper: db);
});
