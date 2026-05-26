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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.translate_rounded, size: 20),
              const SizedBox(width: 8),
              Text('translator.title'.tr()),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            dividerColor: Colors.transparent,
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
