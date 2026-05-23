import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/translator_repository.dart';

class LangPair {
  const LangPair(this.source, this.target);
  final String source;
  final String target;

  LangPair swap() => LangPair(target, source);
}

class LangPairNotifier extends StateNotifier<LangPair> {
  LangPairNotifier() : super(const LangPair('en', 'ru'));
  void setSource(String s) => state = LangPair(s, state.target);
  void setTarget(String t) => state = LangPair(state.source, t);
  void swap() => state = state.swap();
}

final StateNotifierProvider<LangPairNotifier, LangPair> langPairProvider =
    StateNotifierProvider<LangPairNotifier, LangPair>((Ref ref) => LangPairNotifier());

/// Supported translator languages (LibreTranslate models loaded in container).
const List<({String code, String name})> kSupportedLangs = <({String code, String name})>[
  (code: 'en', name: 'English'),
  (code: 'ru', name: 'Russian'),
  (code: 'kk', name: 'Kazakh'),
  (code: 'es', name: 'Spanish'),
  (code: 'de', name: 'German'),
  (code: 'fr', name: 'French'),
  (code: 'zh', name: 'Chinese'),
];

final FutureProviderFamily<List<TranslationDto>, bool> historyProvider =
    FutureProvider.family<List<TranslationDto>, bool>(
  (Ref ref, bool favoritesOnly) =>
      ref.read(translatorRepositoryProvider).history(favoritesOnly: favoritesOnly),
);
