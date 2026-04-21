// lib/features/templates/marketplace/template_marketplace_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app_theme.dart';
import 'template_preview_screen.dart';

class TemplateMarketplaceScreen extends StatefulWidget {
  const TemplateMarketplaceScreen({super.key});
  @override
  State<TemplateMarketplaceScreen> createState() =>
      _TemplateMarketplaceScreenState();
}

class _TemplateMarketplaceScreenState extends State<TemplateMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _templates = [];
  bool _loading = false;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All', 'For You', 'Trending', 'Travel', 'Beat', 'Lyrics', 'Vlog', 'Fun', 'Love'
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _loadMockData();
  }

  void _loadMockData() {
    setState(() => _loading = true);
    // Simulating API delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _templates = _mockTemplates;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Container(
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Search templates',
              prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textTertiary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
          onTap: (i) {
             setState(() => _selectedCategory = _categories[i]);
          },
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
        : RefreshIndicator(
            onRefresh: () async {
              _loadMockData();
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                if (_selectedCategory != 'All' && template['category'] != _selectedCategory) {
                  return const SizedBox.shrink();
                }
                return _TemplateItem(template: template);
              },
            ),
          ),
    );
  }
}

class _TemplateItem extends StatelessWidget {
  final Map<String, dynamic> template;
  const _TemplateItem({required this.template});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TemplatePreviewScreen(initialTemplate: template),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: template['thumbnail_url'],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppTheme.bg3),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            // Info
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template['name'],
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        template['usage_count'],
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      const Spacer(),
                      if (template['is_premium'])
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                           decoration: BoxDecoration(
                             color: AppTheme.accent3,
                             borderRadius: BorderRadius.circular(2),
                           ),
                           child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                         ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final List<Map<String, dynamic>> _mockTemplates = [
  {
    'id': '1',
    'name': 'Cinematic Travel Vibe',
    'thumbnail_url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
    'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-beach-resort-and-palm-trees-1153-large.mp4',
    'category': 'Travel',
    'is_premium': false,
    'author': 'TravelVlogs',
    'usage_count': '1.2M',
  },
  {
    'id': '2',
    'name': 'Urban Night Transitions',
    'thumbnail_url': 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=500&q=80',
    'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-city-lights-at-night-14002-large.mp4',
    'category': 'Trending',
    'is_premium': true,
    'author': 'StreetSnap',
    'usage_count': '850K',
  },
  {
    'id': '3',
    'name': 'Slow Motion Beat Sync',
    'thumbnail_url': 'https://images.unsplash.com/photo-1493225255756-d9584f8606e9?w=500&q=80',
    'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-man-dancing-under-flashing-lights-2340-large.mp4',
    'category': 'Beat',
    'is_premium': false,
    'author': 'DanceMaster',
    'usage_count': '3.4M',
  },
  {
    'id': '4',
    'name': 'Aesthetic Vlog Intro',
    'thumbnail_url': 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=500&q=80',
    'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-girl-taking-photos-with-a-vintage-camera-34505-large.mp4',
    'category': 'Vlog',
    'is_premium': false,
    'author': 'LifeStyle',
    'usage_count': '500K',
  },
  {
    'id': '5',
    'name': 'Neon Glitch Effect',
    'thumbnail_url': 'https://images.unsplash.com/photo-1550745165-9bc0b252728f?w=500&q=80',
    'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-retro-gaming-screen-with-glitch-effect-44222-large.mp4',
    'category': 'Trending',
    'is_premium': true,
    'author': 'CyberPunk',
    'usage_count': '1.1M',
  },
  {
    'id': '6',
    'name': 'Nature Breath',
    'thumbnail_url': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=500&q=80',
    'video_url': 'https://assets.mixkit.co/videos/preview/mixkit-sunlight-streaming-through-the-trees-of-a-forest-4088-large.mp4',
    'category': 'For You',
    'is_premium': false,
    'author': 'EarthExplorer',
    'usage_count': '2.2M',
  },
];
