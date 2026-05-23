import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

class GamesHubPage extends ConsumerWidget {
  const GamesHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('games.title'.tr())),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: <Widget>[
          _GameCard(
            title: 'games.word_match.title'.tr(),
            subtitle: 'games.word_match.subtitle'.tr(),
            icon: Icons.style_outlined,
            color: const Color(0xFF4CAF50),
            onTap: () => _pickModeAndGo(context, Routes.gameWordMatch),
          ),
          _GameCard(
            title: 'games.word_scramble.title'.tr(),
            subtitle: 'games.word_scramble.subtitle'.tr(),
            icon: Icons.shuffle_rounded,
            color: const Color(0xFF2196F3),
            onTap: () => _pickModeAndGo(context, Routes.gameWordScramble),
          ),
          _GameCard(
            title: 'games.sentence_builder.title'.tr(),
            subtitle: 'games.sentence_builder.subtitle'.tr(),
            icon: Icons.short_text_rounded,
            color: const Color(0xFF9C27B0),
            onTap: () => _pickModeAndGo(context, Routes.gameSentenceBuilder),
          ),
          _GameCard(
            title: 'games.hangman.title'.tr(),
            subtitle: 'games.hangman.subtitle'.tr(),
            icon: Icons.gesture_rounded,
            color: const Color(0xFFE91E63),
            onTap: () => _pickModeAndGo(context, Routes.gameHangman),
          ),
        ],
      ),
    );
  }

  Future<void> _pickModeAndGo(BuildContext context, String route) async {
    final String? topic = await showDialog<String?>(
      context: context,
      builder: (BuildContext c) => const _TopicDialog(),
    );
    // null = user cancelled, '' = default mode, non-empty = custom topic
    if (topic == null) return;
    if (!context.mounted) return;
    context.push(route, extra: topic.isEmpty ? null : topic);
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog();

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('games.choose_mode'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'games.custom_topic_hint'.tr(),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'games.topic_placeholder'.tr(),
              prefixIcon: const Icon(Icons.auto_awesome_rounded),
            ),
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('common.cancel'.tr()),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(''),
          icon: const Icon(Icons.shuffle_rounded, size: 18),
          label: Text('games.default_mode'.tr()),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
        ),
        FilledButton.icon(
          onPressed: () {
            final String t = _ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.of(context).pop(t);
          },
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text('games.ai_mode'.tr()),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
