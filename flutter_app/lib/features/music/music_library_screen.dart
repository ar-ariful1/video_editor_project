// lib/features/music/music_library_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../app_theme.dart';
import '../../core/utils/utils.dart';

class MusicTrack {
  final String id, title, artist, genre, mood, url;
  final double durationSeconds, bpm;
  final bool isPremium;
  const MusicTrack(
      {required this.id,
      required this.title,
      required this.artist,
      required this.genre,
      required this.mood,
      required this.url,
      required this.durationSeconds,
      required this.bpm,
      this.isPremium = false});
}

class MusicLibraryScreen extends StatefulWidget {
  final void Function(MusicTrack) onSelected;
  const MusicLibraryScreen({super.key, required this.onSelected});
  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  final _player = AudioPlayer();
  final _searchCtrl = TextEditingController();
  String? _playingId;
  bool _playing = false;
  String _selectedMood = 'All';
  String _selectedGenre = 'All';

  static const _moods = [
    'All',
    'Happy',
    'Sad',
    'Energetic',
    'Calm',
    'Romantic',
    'Dramatic',
    'Funny'
  ];
  static const _genres = [
    'All',
    'Pop',
    'Hip Hop',
    'Electronic',
    'Classical',
    'Jazz',
    'Rock',
    'R&B',
    'Lo-Fi'
  ];

  // Sample tracks (replaced by API in production)
  static final _tracks = [
    const MusicTrack(
        id: '1',
        title: 'Summer Vibes',
        artist: 'CapCut Music',
        genre: 'Pop',
        mood: 'Happy',
        url: '',
        durationSeconds: 120,
        bpm: 128),
    const MusicTrack(
        id: '2',
        title: 'Late Night Drive',
        artist: 'CapCut Music',
        genre: 'Lo-Fi',
        mood: 'Calm',
        url: '',
        durationSeconds: 180,
        bpm: 85),
    const MusicTrack(
        id: '3',
        title: 'Power Up',
        artist: 'CapCut Music',
        genre: 'Electronic',
        mood: 'Energetic',
        url: '',
        durationSeconds: 145,
        bpm: 140,
        isPremium: true),
    const MusicTrack(
        id: '4',
        title: 'Moonlight Sonata',
        artist: 'CapCut Music',
        genre: 'Classical',
        mood: 'Sad',
        url: '',
        durationSeconds: 200,
        bpm: 60),
    const MusicTrack(
        id: '5',
        title: 'Street Flow',
        artist: 'CapCut Music',
        genre: 'Hip Hop',
        mood: 'Energetic',
        url: '',
        durationSeconds: 165,
        bpm: 95),
    const MusicTrack(
        id: '6',
        title: 'Breezy Day',
        artist: 'CapCut Music',
        genre: 'Pop',
        mood: 'Happy',
        url: '',
        durationSeconds: 130,
        bpm: 110),
    const MusicTrack(
        id: '7',
        title: 'Wedding Bells',
        artist: 'CapCut Music',
        genre: 'Classical',
        mood: 'Romantic',
        url: '',
        durationSeconds: 240,
        bpm: 72,
        isPremium: true),
    const MusicTrack(
        id: '8',
        title: 'Neon Lights',
        artist: 'CapCut Music',
        genre: 'Electronic',
        mood: 'Energetic',
        url: '',
        durationSeconds: 190,
        bpm: 130),
  ];

  List<MusicTrack> get _filtered {
    return _tracks.where((t) {
      final q = _searchCtrl.text.toLowerCase();
      final matchSearch = q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q);
      final matchMood = _selectedMood == 'All' || t.mood == _selectedMood;
      final matchGenre = _selectedGenre == 'All' || t.genre == _selectedGenre;
      return matchSearch && matchMood && matchGenre;
    }).toList();
  }

  Future<void> _playPreview(MusicTrack track) async {
    if (_playingId == track.id && _playing) {
      await _player.pause();
      setState(() {
        _playing = false;
      });
      return;
    }
    setState(() {
      _playingId = track.id;
      _playing = false;
    });
    try {
      if (track.url.isNotEmpty) {
        await _player.setUrl(track.url);
        await _player.play();
      }
      setState(() => _playing = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg2,
        title: const Text('Music Library'),
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Search music…',
              hintStyle: TextStyle(color: AppTheme.textTertiary),
              prefixIcon:
                  Icon(Icons.search, color: AppTheme.textTertiary, size: 18),
              filled: true,
              fillColor: Color(0xFF1E1E28),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppTheme.border)),
            ),
          ),
        ),

        // Mood filter
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _moods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => _FilterChip(
                label: _moods[i],
                selected: _selectedMood == _moods[i],
                onTap: () => setState(() => _selectedMood = _moods[i])),
          ),
        ),
        const SizedBox(height: 6),

        // Genre filter
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _genres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => _FilterChip(
                label: _genres[i],
                selected: _selectedGenre == _genres[i],
                onTap: () => setState(() => _selectedGenre = _genres[i])),
          ),
        ),
        const SizedBox(height: 8),

        // Track list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No tracks found',
                      style: TextStyle(color: AppTheme.textTertiary)))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: AppTheme.border, indent: 68),
                  itemBuilder: (_, i) => _TrackTile(
                    track: filtered[i],
                    isPlaying: _playingId == filtered[i].id && _playing,
                    onPlayTap: () => _playPreview(filtered[i]),
                    onSelect: () {
                      _player.stop();
                      widget.onSelected(filtered[i]);
                      Navigator.pop(context);
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.bg3,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? AppTheme.accent : AppTheme.border),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textTertiary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
}

class _TrackTile extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final VoidCallback onPlayTap, onSelect;
  const _TrackTile(
      {required this.track,
      required this.isPlaying,
      required this.onPlayTap,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: GestureDetector(
          onTap: onPlayTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPlaying ? AppTheme.accent : AppTheme.bg3,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isPlaying ? Colors.white : AppTheme.textSecondary,
                size: 24),
          ),
        ),
        title: Row(children: [
          Expanded(
              child: Text(track.title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14))),
          if (track.isPremium)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppTheme.accent3.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('PRO',
                    style: TextStyle(
                        color: AppTheme.accent3,
                        fontSize: 9,
                        fontWeight: FontWeight.w800))),
        ]),
        subtitle: Row(children: [
          Text(track.artist,
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          const Text(' · ', style: TextStyle(color: AppTheme.textTertiary)),
          Text(formatDuration(track.durationSeconds),
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          const Text(' · ', style: TextStyle(color: AppTheme.textTertiary)),
          Text('${track.bpm.toInt()} BPM',
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
        ]),
        trailing: TextButton(
          onPressed: onSelect,
          child: const Text('Use',
              style: TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.w600)),
        ),
      );
}

