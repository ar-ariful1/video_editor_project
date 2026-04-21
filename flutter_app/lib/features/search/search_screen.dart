// lib/features/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../app_theme.dart';
import '../../core/models/video_project.dart';
import '../../core/repositories/project_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:async';

// ── BLoC ──────────────────────────────────────────────────────────────────────

abstract class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class SearchCleared extends SearchEvent {
  const SearchCleared();
}

class _RecentSearchesLoaded extends SearchEvent {
  final List<String> recent;
  const _RecentSearchesLoaded(this.recent);
  @override
  List<Object?> get props => [recent];
}

class _SearchResultsLoaded extends SearchEvent {
  final List<VideoProject> projectResults;
  final List<Map<String, dynamic>> templateResults;
  const _SearchResultsLoaded(this.projectResults, this.templateResults);
  @override
  List<Object?> get props => [projectResults, templateResults];
}

class _SearchFailed extends SearchEvent {
  const _SearchFailed();
}

class _RecentSearchesUpdated extends SearchEvent {
  final List<String> recent;
  const _RecentSearchesUpdated(this.recent);
  @override
  List<Object?> get props => [recent];
}

class SearchState extends Equatable {
  final String query;
  final List<VideoProject> projectResults;
  final List<Map<String, dynamic>> templateResults;
  final bool isLoading;
  final List<String> recentSearches;

  const SearchState(
      {this.query = '',
      this.projectResults = const [],
      this.templateResults = const [],
      this.isLoading = false,
      this.recentSearches = const []});

  SearchState copyWith(
          {String? query,
          List<VideoProject>? projectResults,
          List<Map<String, dynamic>>? templateResults,
          bool? isLoading,
          List<String>? recentSearches}) =>
      SearchState(
          query: query ?? this.query,
          projectResults: projectResults ?? this.projectResults,
          templateResults: templateResults ?? this.templateResults,
          isLoading: isLoading ?? this.isLoading,
          recentSearches: recentSearches ?? this.recentSearches);

  @override
  List<Object?> get props =>
      [query, projectResults, templateResults, isLoading];
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  Timer? _debounce;
  static const _apiBase = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api.yourapp.com');

  SearchBloc() : super(const SearchState()) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchCleared>(_onCleared);
    on<_RecentSearchesLoaded>((event, emit) =>
        emit(state.copyWith(recentSearches: event.recent)));
    on<_RecentSearchesUpdated>((event, emit) =>
        emit(state.copyWith(recentSearches: event.recent)));
    on<_SearchResultsLoaded>((event, emit) => emit(state.copyWith(
        projectResults: event.projectResults,
        templateResults: event.templateResults,
        isLoading: false)));
    on<_SearchFailed>((event, emit) => emit(state.copyWith(isLoading: false)));

    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList('recent_searches') ?? [];
    add(_RecentSearchesLoaded(recent));
  }

  Future<void> _saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList('recent_searches') ?? [];
    recent.remove(query);
    recent.insert(0, query);
    if (recent.length > 10) recent.removeLast();
    await prefs.setStringList('recent_searches', recent);
    add(_RecentSearchesUpdated(recent));
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    emit(state.copyWith(query: event.query));
    _debounce?.cancel();
    if (event.query.trim().isEmpty) {
      emit(state
          .copyWith(projectResults: [], templateResults: [], isLoading: false));
      return;
    }
    emit(state.copyWith(isLoading: true));
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _search(event.query));
  }

  Future<void> _search(String query) async {
    try {
      final projects = await ProjectRepository().getLocalProjects();
      final filteredProjects = projects
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .take(5)
          .toList();

      List<Map<String, dynamic>> templates = [];
      try {
        final res = await Dio().get('$_apiBase/templates',
            queryParameters: {'q': query, 'limit': 6});
        templates =
            List<Map<String, dynamic>>.from(res.data['templates'] ?? []);
      } catch (_) {}

      add(_SearchResultsLoaded(filteredProjects, templates));
      await _saveSearch(query);
    } catch (_) {
      add(const _SearchFailed());
    }
  }

  void _onCleared(SearchCleared event, Emitter<SearchState> emit) {
    _debounce?.cancel();
    emit(state.copyWith(
        query: '', projectResults: [], templateResults: [], isLoading: false));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();
  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
          onChanged: (q) =>
              context.read<SearchBloc>().add(SearchQueryChanged(q)),
          decoration: InputDecoration(
            hintText: 'Search projects, templates, music…',
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            border: InputBorder.none,
            suffixIcon: BlocBuilder<SearchBloc, SearchState>(
              builder: (_, state) => state.query.isNotEmpty
                  ? IconButton(
                      icon:
                          const Icon(Icons.close, color: AppTheme.textTertiary),
                      onPressed: () {
                        _ctrl.clear();
                        context.read<SearchBloc>().add(const SearchCleared());
                      })
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (ctx, state) {
          if (state.isLoading)
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent));

          if (state.query.isEmpty)
            return _RecentSearches(
              recent: state.recentSearches,
              onTap: (q) {
                _ctrl.text = q;
                _ctrl.selection =
                    TextSelection.fromPosition(TextPosition(offset: q.length));
                ctx.read<SearchBloc>().add(SearchQueryChanged(q));
              },
            );

          if (state.projectResults.isEmpty && state.templateResults.isEmpty) {
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Text('🔍', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text('No results for "${state.query}"',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Try different keywords',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 13)),
                ]));
          }

          return ListView(children: [
            if (state.projectResults.isNotEmpty) ...[
              _SectionHeader('Projects (${state.projectResults.length})'),
              ...state.projectResults.map((p) => ListTile(
                    leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: AppTheme.bg3,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.movie_creation_outlined,
                            color: AppTheme.textSecondary, size: 20)),
                    title: Text(p.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: Text(
                        '${p.resolution.label} · ${p.computedDuration.toStringAsFixed(0)}s',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/editor',
                          arguments: {'projectId': p.id});
                    },
                  )),
            ],
            if (state.templateResults.isNotEmpty) ...[
              _SectionHeader('Templates (${state.templateResults.length})'),
              ...state.templateResults.map((t) => ListTile(
                    leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: AppTheme.bg3,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.auto_stories_rounded,
                            color: AppTheme.textSecondary, size: 20)),
                    title: Text(t['name'] ?? '',
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: Text(t['category'] ?? '',
                        style: const TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12)),
                    trailing: t['is_premium'] == true
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppTheme.accent3.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4)),
                            child: const Text('PRO',
                                style: TextStyle(
                                    color: AppTheme.accent3,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/templates');
                    },
                  )),
            ],
          ]);
        },
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final List<String> recent;
  final void Function(String) onTap;
  const _RecentSearches({required this.recent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty)
      return const Center(
          child: Text('Type to search…',
              style: TextStyle(color: AppTheme.textTertiary)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader('Recent Searches'),
      ...recent.map((q) => ListTile(
            leading: const Icon(Icons.history_rounded,
                color: AppTheme.textTertiary, size: 18),
            title: Text(q,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            onTap: () => onTap(q),
            trailing: const Icon(Icons.north_west_rounded,
                color: AppTheme.textTertiary, size: 14),
          )),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );
}

