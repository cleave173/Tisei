import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../widgets/translator_camera_tab.dart';
import '../widgets/translator_history_tab.dart';
import '../widgets/translator_text_tab.dart';
import '../widgets/translator_voice_tab.dart';

class TranslatorPage extends StatelessWidget {
  const TranslatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color onPrimary = Theme.of(context).colorScheme.onPrimary;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          title: Text('translator.title'.tr()),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: onPrimary,
            labelColor: onPrimary,
            unselectedLabelColor: onPrimary.withValues(alpha: 0.7),
            tabs: <Widget>[
              Tab(icon: const Icon(Icons.text_fields), text: 'translator.text'.tr()),
              Tab(icon: const Icon(Icons.mic), text: 'translator.voice'.tr()),
              Tab(icon: const Icon(Icons.camera_alt), text: 'translator.camera'.tr()),
              Tab(icon: const Icon(Icons.history), text: 'translator.history'.tr()),
              Tab(icon: const Icon(Icons.star), text: 'translator.favorites'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            TranslatorTextTab(),
            TranslatorVoiceTab(),
            TranslatorCameraTab(),
            TranslatorHistoryTab(favoritesOnly: false),
            TranslatorHistoryTab(favoritesOnly: true),
          ],
        ),
      ),
    );
  }
}
