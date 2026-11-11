import '../../../core/database/app_database.dart';

/// One past use of a note, newest first when passed to the helpers below.
class NoteUse {
  const NoteUse({required this.note, required this.categoryId});
  final String note;
  final String categoryId;
}

/// Lowercases, strips punctuation and collapses whitespace so "Swiggy - dinner"
/// and "swiggy dinner" compare equal.
String normalizeNote(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r' +'), ' ');

Set<String> _tokens(String normalized) =>
    normalized.split(' ').where((token) => token.length >= 2).toSet();

/// Distinct notes, most recently used first, keeping the latest spelling.
List<String> recentNotesFrom(List<NoteUse> uses, {int limit = 8}) {
  final seen = <String>{};
  final result = <String>[];
  for (final use in uses) {
    final key = normalizeNote(use.note);
    if (key.isEmpty || !seen.add(key)) continue;
    result.add(use.note);
    if (result.length == limit) break;
  }
  return result;
}

/// Past notes matching [query]: whole-note prefix matches first, then word
/// prefix, then substring; ties go to the most used, then most recent note.
List<String> matchingNotesFrom(
  List<NoteUse> uses,
  String query, {
  int limit = 5,
}) {
  final q = normalizeNote(query);
  if (q.isEmpty) return const [];

  final display = <String, String>{};
  final counts = <String, int>{};
  final firstSeen = <String, int>{};
  for (var i = 0; i < uses.length; i++) {
    final key = normalizeNote(uses[i].note);
    if (key.isEmpty || key == q) continue;
    display.putIfAbsent(key, () => uses[i].note);
    firstSeen.putIfAbsent(key, () => i);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  int? tier(String key) {
    if (key.startsWith(q)) return 0;
    if (key.contains(' $q')) return 1;
    if (key.contains(q)) return 2;
    return null;
  }

  final matches = [
    for (final key in display.keys)
      if (tier(key) != null) key,
  ];
  matches.sort((a, b) {
    final byTier = tier(a)!.compareTo(tier(b)!);
    if (byTier != 0) return byTier;
    final byCount = counts[b]!.compareTo(counts[a]!);
    if (byCount != 0) return byCount;
    return firstSeen[a]!.compareTo(firstSeen[b]!);
  });
  return [for (final key in matches.take(limit)) display[key]!];
}

/// Picks a category for [note] from the user's own history, falling back to
/// built-in keywords. Only [activeCategories] can be returned.
String? suggestCategoryFrom(
  List<NoteUse> uses,
  List<CategoryRow> activeCategories,
  String note,
) {
  final q = normalizeNote(note);
  if (q.length < 2 || activeCategories.isEmpty) return null;
  final activeIds = {for (final category in activeCategories) category.id};
  return _fromHistory(uses, activeIds, q) ?? _fromKeywords(activeCategories, q);
}

String? _fromHistory(List<NoteUse> uses, Set<String> activeIds, String q) {
  final queryTokens = _tokens(q);
  final scores = <String, double>{};
  for (var i = 0; i < uses.length; i++) {
    if (!activeIds.contains(uses[i].categoryId)) continue;
    final key = normalizeNote(uses[i].note);
    double similarity;
    if (key == q) {
      similarity = 1;
    } else if (q.length >= 3 && key.startsWith(q)) {
      similarity = .6;
    } else {
      final pastTokens = _tokens(key);
      final union = queryTokens.union(pastTokens).length;
      similarity = union == 0
          ? 0
          : queryTokens.intersection(pastTokens).length / union;
    }
    if (similarity < .5) continue;
    // Recent uses count more, so a changed habit wins over time.
    final recency = 1 / (1 + i / 25);
    scores.update(
      uses[i].categoryId,
      (score) => score + similarity * recency,
      ifAbsent: () => similarity * recency,
    );
  }
  if (scores.isEmpty) return null;
  return scores.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

String? _fromKeywords(List<CategoryRow> activeCategories, String q) {
  final padded = ' $q ';
  String? bestId;
  var bestHits = 0;
  for (final category in activeCategories) {
    final name = normalizeNote(category.name);
    final keywords = {name, ...?categoryKeywords[name]};
    final hits = keywords
        .where((keyword) => keyword.isNotEmpty && padded.contains(' $keyword '))
        .length;
    if (hits > bestHits) {
      bestHits = hits;
      bestId = category.id;
    }
  }
  return bestId;
}

/// Built-in keywords per seeded category, keyed by normalized category name.
/// Custom categories still match on their own name.
const categoryKeywords = <String, List<String>>{
  // Expense
  'food dining': [
    'swiggy',
    'zomato',
    'restaurant',
    'lunch',
    'dinner',
    'breakfast',
    'cafe',
    'coffee',
    'tea',
    'snacks',
    'pizza',
    'burger',
    'dominos',
    'mcdonalds',
    'kfc',
    'starbucks',
    'food',
    'meal',
    'biryani',
    'dine',
    'eating out',
  ],
  'groceries': [
    'grocery',
    'vegetables',
    'veggies',
    'fruits',
    'milk',
    'bigbasket',
    'blinkit',
    'zepto',
    'instamart',
    'dmart',
    'kirana',
    'ration',
    'eggs',
    'bread',
    'supermarket',
  ],
  'transportation': [
    'uber',
    'ola',
    'rapido',
    'taxi',
    'cab',
    'auto',
    'metro',
    'bus',
    'train',
    'petrol',
    'diesel',
    'fuel',
    'cng',
    'parking',
    'toll',
    'fastag',
    'irctc',
  ],
  'vehicle maintenance': [
    'car service',
    'bike service',
    'servicing',
    'tyre',
    'tyres',
    'puncture',
    'car wash',
    'mechanic',
    'oil change',
    'battery',
  ],
  'housing utilities': [
    'rent',
    'electricity',
    'water bill',
    'gas bill',
    'lpg',
    'cylinder',
    'wifi',
    'broadband',
    'internet',
    'maintenance',
    'society',
    'recharge',
    'mobile bill',
    'phone bill',
    'dth',
  ],
  'shopping': [
    'amazon',
    'flipkart',
    'myntra',
    'ajio',
    'meesho',
    'clothes',
    'shoes',
    'shopping',
    'mall',
  ],
  'household': [
    'furniture',
    'utensils',
    'cleaning',
    'detergent',
    'maid',
    'cook',
    'plumber',
    'electrician',
    'appliance',
    'repair',
  ],
  'health medical': [
    'doctor',
    'hospital',
    'medicine',
    'medicines',
    'pharmacy',
    'chemist',
    'apollo',
    'clinic',
    'dental',
    'dentist',
    'checkup',
    'pharmeasy',
    '1mg',
    'lab test',
  ],
  'personal care': [
    'salon',
    'haircut',
    'spa',
    'parlour',
    'grooming',
    'cosmetics',
    'nykaa',
    'skincare',
  ],
  'travel stay': [
    'flight',
    'hotel',
    'airbnb',
    'oyo',
    'makemytrip',
    'goibibo',
    'trip',
    'vacation',
    'holiday',
    'resort',
  ],
  'entertainment': [
    'movie',
    'movies',
    'netflix',
    'prime',
    'hotstar',
    'spotify',
    'bookmyshow',
    'pvr',
    'inox',
    'concert',
    'game',
    'games',
  ],
  'education': [
    'school',
    'college',
    'tuition',
    'fees',
    'course',
    'books',
    'udemy',
    'coursera',
    'exam',
  ],
  'family gifts': ['gift', 'gifts', 'birthday', 'wedding', 'anniversary'],
  'financial payments': [
    'emi',
    'loan',
    'credit card',
    'insurance',
    'premium',
    'sip',
    'tax',
  ],
  'donations': [
    'donation',
    'charity',
    'temple',
    'church',
    'mosque',
    'gurudwara',
    'ngo',
  ],
  // Income
  'salary': ['salary', 'payroll', 'stipend', 'wages', 'bonus'],
  'business': ['business', 'sales', 'invoice', 'revenue'],
  'freelancing': [
    'freelance',
    'upwork',
    'fiverr',
    'gig',
    'consulting',
    'project',
  ],
  'investments': [
    'dividend',
    'interest',
    'mutual fund',
    'stocks',
    'shares',
    'fd',
    'maturity',
    'capital gain',
  ],
  'rental income': ['rent', 'rental', 'tenant', 'lease'],
  'gifts rewards': ['gift', 'cashback', 'reward', 'rewards', 'prize'],
  'refunds': ['refund', 'refunded', 'reversal', 'returned'],
};
