import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import 'data/categories_repository.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(appDatabaseProvider));
});

final activeCategoriesByTypeProvider =
    StreamProvider.family<List<CategoryRow>, String>((ref, type) {
      return ref.watch(categoriesRepositoryProvider).watchActiveByType(type);
    });

/// Active categories for transaction entry, most recently used first.
final recentCategoriesByTypeProvider =
    StreamProvider.family<List<CategoryRow>, String>((ref, type) {
      return ref
          .watch(categoriesRepositoryProvider)
          .watchActiveByTypeByRecentUse(type);
    });

final allCategoriesByTypeProvider =
    StreamProvider.family<List<CategoryRow>, String>((ref, type) {
      return ref.watch(categoriesRepositoryProvider).watchAllByType(type);
    });
