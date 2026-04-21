// lib/features/favorites/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_theme.dart';
import '../../core/widgets/error_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<String> _savedTemplateIds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedTemplateIds = prefs.getStringList('saved_templates') ?? [];
      _loading = false;
    });
  }

  Future<void> _removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_templates') ?? [];
    list.remove(id);
    await prefs.setStringList('saved_templates', list);
    setState(() => _savedTemplateIds = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg2,
        title: const Text('Saved'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.accent,
          tabs: const [Tab(text: 'Templates'), Tab(text: 'Music')],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(controller: _tabs, children: [
              // Saved templates
              _savedTemplateIds.isEmpty
                  ? const EmptyStateWidget(
                      emoji: '❤️',
                      title: 'No saved templates',
                      subtitle:
                          'Browse templates and tap the heart icon to save them here.',
                      actionLabel: 'Browse Templates')
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.7),
                      itemCount: _savedTemplateIds.length,
                      itemBuilder: (_, i) => Stack(children: [
                        Container(
                          decoration: BoxDecoration(
                              color: AppTheme.bg2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border)),
                          child: Column(children: [
                            Expanded(
                                child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(11)),
                                    child: Container(
                                        color: AppTheme.bg3,
                                        child: const Center(
                                            child: Text('🎬',
                                                style: TextStyle(
                                                    fontSize: 36)))))),
                            Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                    'Template ${_savedTemplateIds[i].substring(0, 6)}',
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                          ]),
                        ),
                        Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () =>
                                  _removeFavorite(_savedTemplateIds[i]),
                              child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.favorite_rounded,
                                      color: Colors.red, size: 16)),
                            )),
                      ]),
                    ),
              // Saved music
              const EmptyStateWidget(
                  emoji: '🎵',
                  title: 'No saved music',
                  subtitle:
                      'Browse the music library and tap the heart to save tracks.'),
            ]),
    );
  }
}

// ── Favorite button widget ─────────────────────────────────────────────────────
class FavoriteButton extends StatefulWidget {
  final String itemId;
  final String itemType; // template | music | effect
  const FavoriteButton(
      {super.key, required this.itemId, required this.itemType});
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool _isFav = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.4, end: 1), weight: 50)
    ]).animate(_ctrl);
    _checkFav();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkFav() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_${widget.itemType}s') ?? [];
    if (mounted) setState(() => _isFav = list.contains(widget.itemId));
  }

  Future<void> _toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'saved_${widget.itemType}s';
    final list = prefs.getStringList(key) ?? [];
    if (_isFav) {
      list.remove(widget.itemId);
    } else {
      list.add(widget.itemId);
      _ctrl.forward(from: 0);
    }
    await prefs.setStringList(key, list);
    setState(() => _isFav = !_isFav);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _toggle,
        child: ScaleTransition(
            scale: _anim,
            child: Icon(
                _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFav ? Colors.red : AppTheme.textTertiary,
                size: 22)),
      );
}
