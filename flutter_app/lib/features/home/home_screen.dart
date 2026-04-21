// lib/features/home/home_screen.dart — Complete home with all CapCut features
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_theme.dart';
import '../../core/bloc/timeline_bloc.dart';
import '../../core/models/video_project.dart' as model;
import '../../core/services/project_storage_service.dart';
import '../../core/utils/utils.dart';
import '../auth/auth_bloc.dart';
import '../editor/editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<model.VideoProject> _projects = [];
  final List<Map<String, dynamic>> _trending = _mockT;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ProjectStorageService().getAllProjects();
      if (mounted) {
        setState(() {
          _projects = p;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _mockT = [
    {
      'id': '1',
      'name': 'Wedding Slideshow',
      'category': 'wedding',
      'thumbnail_url': null,
      'is_premium': false,
      'rating': 4.8,
      'download_count': 12400
    },
    {
      'id': '2',
      'name': 'Travel Vlog Intro',
      'category': 'travel',
      'thumbnail_url': null,
      'is_premium': false,
      'rating': 4.7,
      'download_count': 9800
    },
    {
      'id': '3',
      'name': 'Birthday Celebration',
      'category': 'birthday',
      'thumbnail_url': null,
      'is_premium': false,
      'rating': 4.6,
      'download_count': 8200
    },
    {
      'id': '4',
      'name': 'Cinematic Title',
      'category': 'cinematic',
      'thumbnail_url': null,
      'is_premium': true,
      'rating': 4.9,
      'download_count': 7100
    },
    {
      'id': '5',
      'name': 'Islamic Content',
      'category': 'islamic',
      'thumbnail_url': null,
      'is_premium': false,
      'rating': 4.8,
      'download_count': 11000
    },
    {
      'id': '6',
      'name': 'Food Reel',
      'category': 'food',
      'thumbnail_url': null,
      'is_premium': false,
      'rating': 4.5,
      'download_count': 6800
    },
    {
      'id': '7',
      'name': 'Business Intro',
      'category': 'business',
      'thumbnail_url': null,
      'is_premium': true,
      'rating': 4.7,
      'download_count': 5900
    },
    {
      'id': '8',
      'name': 'Fashion Show',
      'category': 'fashion',
      'thumbnail_url': null,
      'is_premium': false,
      'rating': 4.4,
      'download_count': 5400
    },
  ];

  Future<void> _newProject() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> media = await picker.pickMultipleMedia();

    if (media.isNotEmpty && mounted) {
      final List<String> paths = media.map((m) => m.path).toList();
      context.read<TimelineBloc>().add(CreateNewProject(
            name: 'Project ${DateTime.now().millisecondsSinceEpoch}',
            initialMedia: paths,
          ));

      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const EditorScreen()));
      _load();
    }
  }

  Future<void> _open(model.VideoProject p) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => EditorScreen(projectId: p.id)));
    _load();
  }

  Future<void> _delete(model.VideoProject p) async {
    final ok = await showConfirmDialog(context,
        title: 'Delete Project',
        message: '"${p.name}" will be permanently deleted.',
        confirmLabel: 'Delete');
    if (ok == true) {
      await ProjectStorageService().deleteProject(p.id);
      _load();
    }
  }

  Future<void> _duplicate(model.VideoProject p) async {
    await ProjectStorageService().duplicateProject(p.id);
    _load();
  }

  Future<void> _runQuickAI(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickVideo(source: ImageSource.gallery);

    if (media != null && mounted) {
      // 1. Create a project with this media
      context.read<TimelineBloc>().add(CreateNewProject(
            name: 'AI $type ${DateTime.now().millisecondsSinceEpoch}',
            initialMedia: [media.path],
          ));

      // 2. Navigate to editor
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const EditorScreen()));

      // 3. (Optional) Auto-trigger AI panel or action via Bloc or Navigation args
      // For now, we just land them in the editor with the clip ready.
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;
    final name = isAuthenticated
        ? ((authState).displayName ?? (authState).email.split('@').first)
        : '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          // Top Bar with Search
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            title: _buildTopSearch(),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: AppTheme.textSecondary),
                onPressed: () {},
              )
            ],
          ),

          // Main Action Cards (New Video / Edit Photo)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _MainActionCard(
                    title: 'New video',
                    icon: Icons.video_call_rounded,
                    color: Colors.white,
                    onTap: _newProject,
                  ),
                  const SizedBox(width: 12),
                  _MainActionCard(
                    title: 'Edit photo',
                    icon: Icons.photo_library_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    onTap: _newProject, // Can refine for photos
                    badge: 'Seedream 4.3',
                  ),
                ],
              ),
            ),
          ),

          // Tools Grid (AutoCut, Retouch, etc.)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildListDelegate([
                _ToolItem(Icons.movie_filter_outlined, 'AutoCut', () => _runQuickAI('autocut')),
                _ToolItem(Icons.face_retouching_natural_outlined, 'Retouch', () => _runQuickAI('retouch')),
                _ToolItem(Icons.cloud_outlined, 'Space', () {}),
                _ToolItem(Icons.auto_fix_high_outlined, 'AI generator', () {}),
                _ToolItem(Icons.auto_awesome_outlined, 'Auto enhance', () {}),
                _ToolItem(Icons.photo_outlined, 'Photo tools', () {}),
                _ToolItem(Icons.storefront_outlined, 'Marketing tools', () {}),
                _ToolItem(Icons.laptop_chromebook_outlined, 'Desktop editor', () {}, badge: 'Free perks'),
                _ToolItem(Icons.person_remove_outlined, 'Remove background', () => _runQuickAI('remove_bg')),
              ]),
            ),
          ),

          // Recent Projects Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  const Text('Recent Projects',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('View all')),
                ],
              ),
            ),
          ),

          // Recent Projects List
          if (_projects.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ProjTile(
                    project: _projects[i],
                    onTap: () => _open(_projects[i]),
                    onDelete: () => _delete(_projects[i]),
                    onDuplicate: () => _duplicate(_projects[i]),
                  ),
                  childCount: _projects.length,
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: _Empty(onTap: _newProject),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ]),
      ),
    );
  }

  Widget _buildTopSearch() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: AppTheme.textTertiary, size: 20),
          const SizedBox(width: 8),
          const Text('Try "Standard 7 days for -"',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _MainActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppTheme.accent, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ToolItem(IconData icon, String label, VoidCallback onTap, {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bg2,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.border),
                ),
                child: Icon(icon, color: AppTheme.textPrimary, size: 24),
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  final model.VideoProject project;
  final VoidCallback onTap, onDelete, onDuplicate;
  const _RecentCard(
      {required this.project,
      required this.onTap,
      required this.onDelete,
      required this.onDuplicate});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        onLongPress: () => showModalBottomSheet(
            context: c,
            backgroundColor: AppTheme.bg2,
            builder: (_) => Wrap(children: [
                  ListTile(
                      leading: const Icon(Icons.edit_rounded,
                          color: AppTheme.textSecondary),
                      title: const Text('Edit',
                          style: TextStyle(color: AppTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(c);
                        onTap();
                      }),
                  ListTile(
                      leading: const Icon(Icons.copy_rounded,
                          color: AppTheme.textSecondary),
                      title: const Text('Duplicate',
                          style: TextStyle(color: AppTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(c);
                        onDuplicate();
                      }),
                  ListTile(
                      leading: const Icon(Icons.delete_rounded,
                          color: AppTheme.accent4),
                      title: const Text('Delete',
                          style: TextStyle(color: AppTheme.accent4)),
                      onTap: () {
                        Navigator.pop(c);
                        onDelete();
                      }),
                ])),
        child: Container(
          width: 110,
          decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Expanded(
                child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(11)),
                    child: Container(
                        color: AppTheme.bg3,
                        child: const Center(
                            child:
                                Text('🎬', style: TextStyle(fontSize: 26)))))),
            Padding(
                padding: const EdgeInsets.all(7),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(formatRelativeTime(project.updatedAt),
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 9)),
                    ])),
          ]),
        ),
      );
}

class _ProjTile extends StatelessWidget {
  final model.VideoProject project;
  final VoidCallback onTap, onDelete, onDuplicate;
  const _ProjTile(
      {required this.project,
      required this.onTap,
      required this.onDelete,
      required this.onDuplicate});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppTheme.bg3,
                    borderRadius: BorderRadius.circular(8)),
                child: const Center(
                    child: Text('🎬', style: TextStyle(fontSize: 20)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(project.name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                      '${project.resolution.label} · ${formatDuration(project.computedDuration)} · ${formatRelativeTime(project.updatedAt)}',
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11)),
                ])),
            PopupMenuButton<String>(
                color: AppTheme.bg2,
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppTheme.textTertiary, size: 18),
                onSelected: (v) {
                  if (v == 'd')
                    onDelete();
                  else if (v == 'dup') onDuplicate();
                },
                itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'dup',
                          child: Text('Duplicate',
                              style: TextStyle(color: AppTheme.textPrimary))),
                      const PopupMenuItem(
                          value: 'd',
                          child: Text('Delete',
                              style: TextStyle(color: AppTheme.accent4))),
                    ]),
          ]),
        ),
      );
}

class _TemplateTile extends StatelessWidget {
  final Map<String, dynamic> t;
  const _TemplateTile({required this.t});
  static const _emojis = {
    'wedding': '💒',
    'travel': '✈️',
    'birthday': '🎂',
    'food': '🍕',
    'business': '💼',
    'fashion': '👗',
    'cinematic': '🎬',
    'islamic': '🕌',
    'gaming': '🎮',
    'music': '🎵'
  };
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: () => Navigator.pushNamed(c, '/templates'),
        child: Container(
          decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: [
            Expanded(
                child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(11)),
                    child: Stack(fit: StackFit.expand, children: [
                      Container(
                          color: AppTheme.bg3,
                          child: Center(
                              child: Text(_emojis[t['category']] ?? '🎬',
                                  style: const TextStyle(fontSize: 36)))),
                      if (t['is_premium'] == true)
                        Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('PRO',
                                    style: TextStyle(
                                        color: AppTheme.accent3,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800)))),
                      if ((t['download_count'] ?? 0) > 10000)
                        Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('🔥',
                                    style: TextStyle(fontSize: 10)))),
                    ]))),
            Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['name'] ?? '',
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: AppTheme.accent3, size: 11),
                        Text(' ${(t['rating'] ?? 0.0).toStringAsFixed(1)}',
                            style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 10))
                      ]),
                    ])),
          ]),
        ),
      );
}

class _Empty extends StatelessWidget {
  final VoidCallback onTap;
  const _Empty({required this.onTap});
  @override
  Widget build(BuildContext c) => Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          const Text('🎬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          const Text('No projects yet',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Start creating — blank project or template',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 22),
          ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New Project',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(c, '/templates'),
              icon: const Icon(Icons.auto_stories_rounded),
              label: const Text('Browse Templates'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)))),
        ]),
      );
}

