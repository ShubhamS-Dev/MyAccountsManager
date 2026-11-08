import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import 'data/categories_repository.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(appDatabaseProvider));
});

final activeCategoriesByTypeProvider = StreamProvider.family((ref, String type) {
  return ref.watch(categoriesRepositoryProvider).watchActiveByType(type);
});
