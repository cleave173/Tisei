import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/translator_providers.dart';

class LangPairBar extends ConsumerWidget {
  const LangPairBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LangPair pair = ref.watch(langPairProvider);
    final LangPairNotifier ctrl = ref.read(langPairProvider.notifier);

    Widget dropdown(String value, void Function(String) onChanged) {
      return Expanded(
        child: DropdownButtonFormField<String>(
          value: value,
          onChanged: (String? v) => v == null ? null : onChanged(v),
          items: kSupportedLangs
              .map((l) => DropdownMenuItem<String>(value: l.code, child: Text(l.name)))
              .toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          dropdown(pair.source, ctrl.setSource),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: ctrl.swap,
          ),
          dropdown(pair.target, ctrl.setTarget),
        ],
      ),
    );
  }
}
