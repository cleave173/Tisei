import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_snack_bar.dart';
import '../../data/translator_repository.dart';
import '../providers/translator_providers.dart';

class TranslatorHistoryTab extends ConsumerWidget {
  const TranslatorHistoryTab({super.key, required this.favoritesOnly});
  final bool favoritesOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TranslationDto>> items = ref.watch(
      historyProvider(favoritesOnly),
    );
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) =>
          Center(child: Text(AppSnackBar.friendlyMessage(e))),
      data: (List<TranslationDto> list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              favoritesOnly
                  ? 'translator.no_favorites'.tr()
                  : 'translator.no_history'.tr(),
            ),
          );
        }
        return Column(
          children: <Widget>[
            if (!favoritesOnly)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(translatorRepositoryProvider)
                          .clearHistory();
                      ref.invalidate(historyProvider(false));
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text('common.clear_all'.tr()),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext c, int i) {
                  final TranslationDto t = list[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        t.sourceText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        t.translatedText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: <Widget>[
                          IconButton(
                            icon: Icon(
                              t.isFavorite ? Icons.star : Icons.star_border,
                              color: t.isFavorite ? Colors.amber : null,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(translatorRepositoryProvider)
                                  .toggleFavorite(t.id);
                              ref.invalidate(historyProvider(false));
                              ref.invalidate(historyProvider(true));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref
                                  .read(translatorRepositoryProvider)
                                  .deleteItem(t.id);
                              ref.invalidate(historyProvider(false));
                              ref.invalidate(historyProvider(true));
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
