import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../learning/data/learning_repository.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../../learning/presentation/widgets/word_card.dart';

/// Vocabulary browser: search across all imported words (CEFR-J + Oxford 5000).
/// Level filter chips + debounced search by lemma / RU / KK translation.
/// Infinite scroll pagination (server-backed, 100 per page).
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const List<String> _levels = <String>['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  static const int _pageSize = 100;

  String? _level = 'A1';
  String _query = '';
  Timer? _debounce;

  final List<WordDto> _items = <WordDto>[];
  final ScrollController _scroll = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _reqSeq = 0; // filters-out stale responses when filters change quickly

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final int mySeq = ++_reqSeq;
    setState(() => _loading = true);
    try {
      final List<WordDto> page = await ref.read(learningRepositoryProvider).searchWords(
            level: _level,
            query: _query.isEmpty ? null : _query,
            limit: _pageSize,
            offset: _items.length,
          );
      if (mySeq != _reqSeq || !mounted) return; // filters changed — drop stale response
      setState(() {
        _items.addAll(page);
        if (page.length < _pageSize) _hasMore = false;
        _loading = false;
      });
    } catch (e) {
      if (mySeq != _reqSeq || !mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
      _reload();
    });
  }

  void _setLevel(String? l) {
    if (_level == l) return;
    setState(() => _level = l);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('vocabulary.title'.tr())),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'vocabulary.search_hint'.tr(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                _Chip(label: 'common.all'.tr(), selected: _level == null,
                    onTap: () => _setLevel(null)),
                for (final String l in _levels)
                  _Chip(label: l, selected: _level == l, onTap: () => _setLevel(l)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: Color(0xFFC62828),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppSnackBar.friendlyMessage(_error),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: const Color(0xFFC62828)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reload,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828)),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(child: Text('vocabulary.empty'.tr()));
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext c, int i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return WordCard(word: _items[i]);
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      ),
    );
  }
}
