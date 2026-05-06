import 'dart:async';

import 'package:flutter/material.dart';

import 'services/society_service.dart';

enum SocietySortOption {
  alphabeticalAsc,
  alphabeticalDesc,
  memberCountHighLow,
  ratingHighLow,
}

enum SocietyRatingFilter {
  any,
  atLeastOne,
  atLeastTwo,
  atLeastThree,
  atLeastFour,
}

class SocietySummary {
  final String name;
  final String description;
  final String category;
  final String imageUrl;
  final IconData icon;
  final int memberCount;
  final double averageRating;
  final bool joined;

  const SocietySummary({
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.icon,
    required this.memberCount,
    required this.averageRating,
    this.joined = false,
  });

  SocietySummary copyWith({
    String? name,
    String? description,
    String? category,
    String? imageUrl,
    IconData? icon,
    int? memberCount,
    double? averageRating,
    bool? joined,
  }) {
    return SocietySummary(
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
      memberCount: memberCount ?? this.memberCount,
      averageRating: averageRating ?? this.averageRating,
      joined: joined ?? this.joined,
    );
  }
}

class SocietiesPage extends StatefulWidget {
  final String? userEmail;
  final String? userAuthToken;

  const SocietiesPage({super.key, this.userEmail, this.userAuthToken});

  @override
  State<SocietiesPage> createState() => _SocietiesPageState();
}

class _SocietiesPageState extends State<SocietiesPage> {
  final TextEditingController _searchController = TextEditingController();
  final SocietyService _societyService = SocietyService();

  late List<SocietySummary> _allSocieties;
  late List<SocietySummary> _filteredSocieties;

  bool _loadingMembership = false;
  bool _joinedOnly = false;
  String _categoryFilter = 'All categories';
  SocietyRatingFilter _ratingFilter = SocietyRatingFilter.any;
  SocietySortOption _sortOption = SocietySortOption.alphabeticalAsc;

  @override
  void initState() {
    super.initState();
    _allSocieties = _seedSocieties();
    _filteredSocieties = List.from(_allSocieties);
    _searchController.addListener(_applyFilters);

    final email = widget.userEmail;
    if (email != null && email.isNotEmpty) {
      _syncMemberships();
    } else {
      _applyFilters();
    }
    // Refresh live average ratings from backend when available
    unawaited(_refreshAverages());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SocietySummary> _seedSocieties() {
    return const [
      SocietySummary(
        name: 'Art Society',
        description:
            'A friendly society for drawing, painting, and creative workshops.',
        category: 'Creative',
        imageUrl:
            'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&auto=format&fit=crop',
        icon: Icons.palette,
        memberCount: 82,
        averageRating: 3.6,
      ),
      SocietySummary(
        name: 'Anime Society',
        description: 'Weekly anime screenings and socials for all fans.',
        category: 'Culture',
        imageUrl:
            'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&auto=format&fit=crop',
        icon: Icons.tv,
        memberCount: 101,
        averageRating: 4.1,
      ),
      SocietySummary(
        name: 'Gaming Society',
        description: 'Casual and competitive gaming events across many genres.',
        category: 'Technology',
        imageUrl:
            'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop',
        icon: Icons.sports_esports,
        memberCount: 174,
        averageRating: 4.1,
      ),
      SocietySummary(
        name: 'Music Society',
        description: 'Jam sessions, open mics, and opportunities to perform.',
        category: 'Creative',
        imageUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop',
        icon: Icons.music_note,
        memberCount: 93,
        averageRating: 4.0,
      ),
      SocietySummary(
        name: 'Photography Club',
        description: 'Photo walks, editing tips, and portfolio feedback.',
        category: 'Creative',
        imageUrl:
            'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800&auto=format&fit=crop',
        icon: Icons.camera_alt,
        memberCount: 64,
        averageRating: 4.1,
      ),
      SocietySummary(
        name: 'Dance Society',
        description:
            'Learn routines and perform at events throughout the year.',
        category: 'Performance',
        imageUrl:
            'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop',
        icon: Icons.music_video,
        memberCount: 77,
        averageRating: 4.0,
      ),
      SocietySummary(
        name: 'Drama Club',
        description: 'Acting workshops, productions, and backstage roles.',
        category: 'Performance',
        imageUrl:
            'https://plus.unsplash.com/premium_photo-1684923604128-c48f46b0cb00?q=80&w=1471&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        icon: Icons.theater_comedy,
        memberCount: 59,
        averageRating: 1.8,
      ),
      SocietySummary(
        name: 'Coding Society',
        description: 'Hack nights, project teams, and interview practice.',
        category: 'Technology',
        imageUrl:
            'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=800&auto=format&fit=crop',
        icon: Icons.code,
        memberCount: 141,
        averageRating: 4.7,
      ),
      SocietySummary(
        name: 'Robotics Club',
        description: 'Build, program, and compete with robotics projects.',
        category: 'Technology',
        imageUrl:
            'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&auto=format&fit=crop',
        icon: Icons.precision_manufacturing,
        memberCount: 48,
        averageRating: 4.3,
      ),
      SocietySummary(
        name: 'Environmental Club',
        description:
            'Campus green projects, cleanups and sustainability events.',
        category: 'Community',
        imageUrl:
            'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=800&auto=format&fit=crop',
        icon: Icons.eco,
        memberCount: 56,
        averageRating: 3.8,
      ),
      SocietySummary(
        name: 'Film Society',
        description: 'Screenings, discussions and filmmaking workshops.',
        category: 'Creative',
        imageUrl:
            'https://plus.unsplash.com/premium_photo-1723867528308-539f3936c339?q=80&w=1926&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        icon: Icons.movie,
        memberCount: 72,
        averageRating: 4.1,
      ),
      SocietySummary(
        name: 'Chess Club',
        description: 'Casual and competitive chess sessions and tournaments.',
        category: 'Games',
        imageUrl:
            'https://images.unsplash.com/photo-1695480542225-bc22cac128d0?q=80&w=695&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
        icon: Icons.sports_esports,
        memberCount: 34,
        averageRating: 2.2,
      ),
      SocietySummary(
        name: 'Cooking Society',
        description: 'Learn new recipes, cook together and share meals.',
        category: 'Lifestyle',
        imageUrl:
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&auto=format&fit=crop',
        icon: Icons.restaurant,
        memberCount: 88,
        averageRating: 4.0,
      ),
      SocietySummary(
        name: 'Entrepreneurship Society',
        description:
            'Startups, pitch nights and networking for student founders.',
        category: 'Professional',
        imageUrl:
            'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&auto=format&fit=crop',
        icon: Icons.lightbulb,
        memberCount: 64,
        averageRating: 3.7,
      ),
    ];
  }

  Future<void> _syncMemberships() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    setState(() {
      _loadingMembership = true;
    });

    final result = await _societyService.getMySocieties(email: email);
    if (!mounted) return;

    if (result['success'] == true) {
      final List<String> names =
          (result['societies'] as List<String>? ?? <String>[]);
      final Set<String> joinedNames = names.toSet();
      _allSocieties = _allSocieties
          .map(
            (society) =>
                society.copyWith(joined: joinedNames.contains(society.name)),
          )
          .toList();
      _applyFilters();
    }

    // When memberships synced, also refresh live averages
    unawaited(_refreshAverages());

    if (mounted) {
      setState(() {
        _loadingMembership = false;
      });
    }
  }

  void _applyFilters() {
    final String query = _searchController.text.trim().toLowerCase();

    List<SocietySummary> next = _allSocieties.where((society) {
      final bool searchMatches =
          query.isEmpty || society.name.toLowerCase().contains(query);
      final bool categoryMatches =
          _categoryFilter == 'All categories' ||
          society.category == _categoryFilter;
      final bool joinedMatches = !_joinedOnly || society.joined;

      final double minRating = switch (_ratingFilter) {
        SocietyRatingFilter.any => 0,
        SocietyRatingFilter.atLeastOne => 1,
        SocietyRatingFilter.atLeastTwo => 2,
        SocietyRatingFilter.atLeastThree => 3,
        SocietyRatingFilter.atLeastFour => 4,
      };
      final bool ratingMatches = society.averageRating >= minRating;

      return searchMatches && categoryMatches && joinedMatches && ratingMatches;
    }).toList();

    switch (_sortOption) {
      case SocietySortOption.alphabeticalAsc:
        next.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SocietySortOption.alphabeticalDesc:
        next.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SocietySortOption.memberCountHighLow:
        next.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        break;
      case SocietySortOption.ratingHighLow:
        next.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
    }

    setState(() {
      _filteredSocieties = next;
    });
  }

  Future<void> _refreshAverages() async {
    try {
      final futures = _allSocieties.map((society) async {
        final res = await _societyService.getReviews(societyName: society.name);
        if (res['success'] == true) {
          final List<dynamic> raw = res['reviews'] as List<dynamic>? ?? [];
          if (raw.isNotEmpty) {
            final ratings = raw
                .map(
                  (m) =>
                      ((m as Map<String, dynamic>)['rating'] as num?)
                          ?.toDouble() ??
                      0.0,
                )
                .toList();
            final double avg = ratings.reduce((a, b) => a + b) / ratings.length;
            final double rounded = double.parse(avg.toStringAsFixed(1));
            return society.copyWith(averageRating: rounded);
          }
        }
        return society;
      }).toList();

      final updated = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _allSocieties = updated;
      });
      _applyFilters();
    } catch (_) {
      // Silently ignore network errors — keep seeded values
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _joinedOnly = false;
      _categoryFilter = 'All categories';
      _ratingFilter = SocietyRatingFilter.any;
      _sortOption = SocietySortOption.alphabeticalAsc;
    });
    _applyFilters();
  }

  List<String> get _categories {
    final Set<String> set = _allSocieties.map((s) => s.category).toSet();
    final List<String> categories = set.toList()..sort();
    return <String>['All categories', ...categories];
  }

  String _sortLabel(SocietySortOption option) {
    switch (option) {
      case SocietySortOption.alphabeticalAsc:
        return 'A-Z';
      case SocietySortOption.alphabeticalDesc:
        return 'Z-A';
      case SocietySortOption.memberCountHighLow:
        return 'Members';
      case SocietySortOption.ratingHighLow:
        return 'Rating';
    }
  }

  String _ratingFilterLabel(SocietyRatingFilter filter) {
    switch (filter) {
      case SocietyRatingFilter.any:
        return 'Any';
      case SocietyRatingFilter.atLeastOne:
        return '1.0+';
      case SocietyRatingFilter.atLeastTwo:
        return '2.0+';
      case SocietyRatingFilter.atLeastThree:
        return '3.0+';
      case SocietyRatingFilter.atLeastFour:
        return '4.0+';
    }
  }

  void _updateSocietyFromDetails({
    required String societyName,
    bool? joined,
    int? memberCount,
    double? averageRating,
  }) {
    setState(() {
      _allSocieties = _allSocieties.map((society) {
        if (society.name != societyName) {
          return society;
        }
        return society.copyWith(
          joined: joined,
          memberCount: memberCount,
          averageRating: averageRating,
        );
      }).toList();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Societies'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by society name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _resetFilters,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          initialValue: _categoryFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(
                                    category == 'All categories'
                                        ? 'All'
                                        : category,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _categoryFilter = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<SocietyRatingFilter>(
                          initialValue: _ratingFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Rating',
                            border: OutlineInputBorder(),
                          ),
                          items: SocietyRatingFilter.values
                              .map(
                                (filter) =>
                                    DropdownMenuItem<SocietyRatingFilter>(
                                      value: filter,
                                      child: Text(_ratingFilterLabel(filter)),
                                    ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _ratingFilter = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<SocietySortOption>(
                          initialValue: _sortOption,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sort',
                            border: OutlineInputBorder(),
                          ),
                          items: SocietySortOption.values
                              .map(
                                (option) => DropdownMenuItem<SocietySortOption>(
                                  value: option,
                                  child: Text(_sortLabel(option)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _sortOption = value;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Joined only'),
                      selected: _joinedOnly,
                      onSelected: (selected) {
                        setState(() {
                          _joinedOnly = selected;
                        });
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                    if (_loadingMembership)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (!_loadingMembership &&
                        widget.userEmail != null &&
                        widget.userEmail!.isNotEmpty)
                      TextButton.icon(
                        onPressed: _syncMemberships,
                        icon: const Icon(Icons.sync),
                        label: const Text('Refresh joined'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredSocieties.isEmpty
                ? _EmptySocietyState(onReset: _resetFilters)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      final int columns = width < 420
                          ? 1
                          : width < 900
                          ? 2
                          : width < 1200
                          ? 3
                          : 4;

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 320,
                        ),
                        itemCount: _filteredSocieties.length,
                        itemBuilder: (context, index) {
                          final society = _filteredSocieties[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SocietyDetailsPage(
                                      name: society.name,
                                      description: society.description,
                                      imageUrl: society.imageUrl,
                                      icon: society.icon,
                                      userEmail: widget.userEmail,
                                      userAuthToken: widget.userAuthToken,
                                      initialJoined: society.joined,
                                      initialMemberCount: society.memberCount,
                                      initialAverageRating:
                                          society.averageRating,
                                      onMembershipChanged: (joined, count) {
                                        _updateSocietyFromDetails(
                                          societyName: society.name,
                                          joined: joined,
                                          memberCount: count,
                                        );
                                      },
                                      onAverageRatingChanged: (rating) {
                                        _updateSocietyFromDetails(
                                          societyName: society.name,
                                          averageRating: rating,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 140,
                                    child: Image.network(
                                      society.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.15),
                                        child: Icon(
                                          society.icon,
                                          size: 60,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  society.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                              if (society.joined)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.green.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Joined',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.green.shade800,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            society.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _MetaPill(
                                                icon: Icons.category,
                                                text: society.category,
                                              ),
                                              _MetaPill(
                                                icon: Icons.people,
                                                text:
                                                    '${society.memberCount} members',
                                              ),
                                              _MetaPill(
                                                icon: Icons.star,
                                                text: society.averageRating
                                                    .toStringAsFixed(1),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(text),
        ],
      ),
    );
  }
}

class MembersPage extends StatefulWidget {
  final String societyName;
  final String? userEmail;

  const MembersPage({super.key, required this.societyName, this.userEmail});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final SocietyService _societyService = SocietyService();
  bool _loading = true;
  List<Map<String, dynamic>> _members = [];
  bool _viewerIsAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final res = await _societyService.getMembers(
      societyName: widget.societyName,
      viewerEmail: widget.userEmail,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _members = (res['members'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _viewerIsAdmin = res['viewer_is_admin'] == true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? 'Could not load members.',
          ),
        ),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members — ${widget.societyName}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
          ? Center(child: Text('No members found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _members.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final m = _members[index];
                final isAdminMember = (m['role'] ?? '') == 'admin';
                return ListTile(
                  leading: CircleAvatar(
                    child: Text((m['up_number'] ?? '?').toString()),
                  ),
                  title: Text(
                    (m['display_name'] ?? m['email'] ?? '').toString(),
                  ),
                  subtitle: Text('UP: ${m['up_number'] ?? ''}'),
                  trailing: _viewerIsAdmin && !isAdminMember
                      ? TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Make admin?'),
                                content: Text(
                                  'Promote ${m['display_name'] ?? m['email']} to admin?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Confirm'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                            final adminEmail = widget.userEmail ?? '';
                            final memberId = (m['id'] as int?);
                            if (memberId == null) return;
                            final res = await _societyService.promoteMember(
                              adminEmail: adminEmail,
                              societyName: widget.societyName,
                              memberId: memberId,
                            );
                            if (!mounted) return;
                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ?? 'Promoted.',
                                  ),
                                ),
                              );
                              await _loadMembers();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ??
                                        'Could not promote.',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Make admin'),
                        )
                      : (isAdminMember ? const Text('Admin') : null),
                );
              },
            ),
    );
  }
}

class _EmptySocietyState extends StatelessWidget {
  final VoidCallback onReset;

  const _EmptySocietyState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'No societies match your filters.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try broadening your search or reset all filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class SocietyReview {
  final int id;
  final String author;
  final String authorDisplayName;
  final int rating;
  final String comment;
  final int likes;
  final int dislikes;
  final String? userReaction;
  final bool canReact;
  final String? adminResponseText;
  final String? adminResponderName;

  const SocietyReview({
    required this.id,
    required this.author,
    required this.authorDisplayName,
    required this.rating,
    required this.comment,
    required this.likes,
    required this.dislikes,
    this.userReaction,
    this.canReact = false,
    this.adminResponseText,
    this.adminResponderName,
  });

  SocietyReview copyWith({
    int? likes,
    int? dislikes,
    String? userReaction,
    bool? canReact,
    String? adminResponseText,
    String? adminResponderName,
  }) {
    return SocietyReview(
      id: id,
      author: author,
      authorDisplayName: authorDisplayName,
      rating: rating,
      comment: comment,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      userReaction: userReaction ?? this.userReaction,
      canReact: canReact ?? this.canReact,
      adminResponseText: adminResponseText ?? this.adminResponseText,
      adminResponderName: adminResponderName ?? this.adminResponderName,
    );
  }
}

enum ReviewSortOption { latest, rating, popularity }

// Mock seeded reviews used when the backend has no reviews (local/demo mode).
final Map<String, List<Map<String, dynamic>>> _seededReviewsData = {
  'Art Society': [
    {
      'id': 1,
      'author': 'alice@example.com',
      'author_display_name': 'Alice*',
      'rating': 5,
      'comment': 'Fantastic workshops and welcoming members.',
      'likes': 4,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 2,
      'author': 'ben@example.com',
      'author_display_name': 'Ben*',
      'rating': 4,
      'comment': 'Great tutors but sometimes crowded.',
      'likes': 2,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 3,
      'author': 'cara@example.com',
      'author_display_name': 'Cara*',
      'rating': 4,
      'comment': 'Lovely community and useful resources.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 4,
      'author': 'dave@example.com',
      'author_display_name': 'Dave*',
      'rating': 3,
      'comment': 'Good overall, could use more crit nights.',
      'likes': 0,
      'dislikes': 1,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Drama Club': [
    {
      'id': 35,
      'author': 'paula@example.com',
      'author_display_name': 'Paula*',
      'rating': 1,
      'comment': 'Shows can be hit-or-miss.',
      'likes': 0,
      'dislikes': 1,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 36,
      'author': 'quentin@example.com',
      'author_display_name': 'Quentin*',
      'rating': 2,
      'comment': 'Friendly group but needs better rehearsal space.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 37,
      'author': 'rachel@example.com',
      'author_display_name': 'Rachel*',
      'rating': 2,
      'comment': 'Good opportunities but inconsistent scheduling.',
      'likes': 0,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 38,
      'author': 'steve@example.com',
      'author_display_name': 'Steve*',
      'rating': 2,
      'comment': 'Nice people; performances need polishing.',
      'likes': 0,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Anime Society': [
    {
      'id': 11,
      'author': 'emma@example.com',
      'author_display_name': 'Emma*',
      'rating': 5,
      'comment': 'Perfect screenings and friendly people.',
      'likes': 6,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 12,
      'author': 'frank@example.com',
      'author_display_name': 'Frank*',
      'rating': 2,
      'comment': 'Too noisy for me at times.',
      'likes': 0,
      'dislikes': 2,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 13,
      'author': 'gina@example.com',
      'author_display_name': 'Gina*',
      'rating': 4,
      'comment': 'Nice selection of shows.',
      'likes': 3,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 14,
      'author': 'harry@example.com',
      'author_display_name': 'Harry*',
      'rating': 3,
      'comment': 'Good events but limited seating.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 15,
      'author': 'ivy@example.com',
      'author_display_name': 'Ivy*',
      'rating': 5,
      'comment': 'Loved the cosplay meet-up!',
      'likes': 4,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Gaming Society': [
    {
      'id': 21,
      'author': 'jack@example.com',
      'author_display_name': 'Jack*',
      'rating': 5,
      'comment': 'Great events and tournaments.',
      'likes': 8,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 22,
      'author': 'kate@example.com',
      'author_display_name': 'Kate*',
      'rating': 4,
      'comment': 'Friendly members and good equipment.',
      'likes': 2,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 23,
      'author': 'liam@example.com',
      'author_display_name': 'Liam*',
      'rating': 3,
      'comment': 'Sometimes schedules clash with classes.',
      'likes': 1,
      'dislikes': 1,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 24,
      'author': 'mona@example.com',
      'author_display_name': 'Mona*',
      'rating': 4,
      'comment': 'Good variety of games.',
      'likes': 3,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Music Society': [
    {
      'id': 31,
      'author': 'nora@example.com',
      'author_display_name': 'Nora*',
      'rating': 5,
      'comment': 'Fantastic concerts and rehearsals.',
      'likes': 5,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 32,
      'author': 'oliver@example.com',
      'author_display_name': 'Oliver*',
      'rating': 4,
      'comment': 'Helpful for improving skills.',
      'likes': 2,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 33,
      'author': 'paul@example.com',
      'author_display_name': 'Paul*',
      'rating': 2,
      'comment': 'Needs better instrument availability.',
      'likes': 0,
      'dislikes': 2,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 34,
      'author': 'queenie@example.com',
      'author_display_name': 'Queenie*',
      'rating': 4,
      'comment': 'Great community performances.',
      'likes': 3,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  // Additional new societies with varied reviews
  'Environmental Club': [
    {
      'id': 41,
      'author': 'rita@example.com',
      'author_display_name': 'Rita*',
      'rating': 4,
      'comment': 'Love the beach cleanups.',
      'likes': 2,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 42,
      'author': 'sam@example.com',
      'author_display_name': 'Sam*',
      'rating': 3,
      'comment': 'Good aims but could be better organised.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 43,
      'author': 'tina@example.com',
      'author_display_name': 'Tina*',
      'rating': 5,
      'comment': 'Informative workshops and lovely people.',
      'likes': 3,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 44,
      'author': 'umar@example.com',
      'author_display_name': 'Umar*',
      'rating': 4,
      'comment': 'Practical and impactful projects.',
      'likes': 0,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 45,
      'author': 'vicky@example.com',
      'author_display_name': 'Vicky*',
      'rating': 3,
      'comment': 'Times could suit students better.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Film Society': [
    {
      'id': 51,
      'author': 'will@example.com',
      'author_display_name': 'Will*',
      'rating': 5,
      'comment': 'Excellent curation of films.',
      'likes': 4,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 52,
      'author': 'xena@example.com',
      'author_display_name': 'Xena*',
      'rating': 4,
      'comment': 'Good discussions afterwards.',
      'likes': 2,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 53,
      'author': 'yara@example.com',
      'author_display_name': 'Yara*',
      'rating': 3,
      'comment': 'Venue could be more comfortable.',
      'likes': 0,
      'dislikes': 1,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 54,
      'author': 'zane@example.com',
      'author_display_name': 'Zane*',
      'rating': 4,
      'comment': 'Friendly and passionate members.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Chess Club': [
    {
      'id': 61,
      'author': 'adam@example.com',
      'author_display_name': 'Adam*',
      'rating': 2,
      'comment': 'Great practice partners.',
      'likes': 2,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 62,
      'author': 'bella@example.com',
      'author_display_name': 'Bella*',
      'rating': 2,
      'comment': 'Friendly but could use coaching sessions.',
      'likes': 0,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 63,
      'author': 'carl@example.com',
      'author_display_name': 'Carl*',
      'rating': 2,
      'comment': 'Well organised tournaments.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 64,
      'author': 'dina@example.com',
      'author_display_name': 'Dina*',
      'rating': 3,
      'comment': 'Meet times clash with lectures sometimes.',
      'likes': 0,
      'dislikes': 2,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Cooking Society': [
    {
      'id': 71,
      'author': 'ellen@example.com',
      'author_display_name': 'Ellen*',
      'rating': 5,
      'comment': 'Loved the international cuisine nights.',
      'likes': 5,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 72,
      'author': 'fred@example.com',
      'author_display_name': 'Fred*',
      'rating': 4,
      'comment': 'Great recipes and practical tips.',
      'likes': 2,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 73,
      'author': 'gina2@example.com',
      'author_display_name': 'Gina2*',
      'rating': 3,
      'comment': 'Sometimes short on ingredients.',
      'likes': 0,
      'dislikes': 1,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 74,
      'author': 'hugo@example.com',
      'author_display_name': 'Hugo*',
      'rating': 4,
      'comment': 'Practical, fun and social.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
  ],
  'Entrepreneurship Society': [
    {
      'id': 81,
      'author': 'iris@example.com',
      'author_display_name': 'Iris*',
      'rating': 4,
      'comment': 'Excellent networking opportunities.',
      'likes': 3,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 82,
      'author': 'john@example.com',
      'author_display_name': 'John*',
      'rating': 3,
      'comment': 'Good speakers but needs more workshops.',
      'likes': 1,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 83,
      'author': 'kira@example.com',
      'author_display_name': 'Kira*',
      'rating': 5,
      'comment': 'Loved the pitch nights.',
      'likes': 4,
      'dislikes': 0,
      'user_reaction': null,
      'can_react': true,
    },
    {
      'id': 84,
      'author': 'leo@example.com',
      'author_display_name': 'Leo*',
      'rating': 2,
      'comment': 'Not enough hands-on mentoring.',
      'likes': 0,
      'dislikes': 2,
      'user_reaction': null,
      'can_react': true,
    },
  ],
};

class SocietyDetailsPage extends StatefulWidget {
  final String name;
  final String description;
  final String imageUrl;
  final IconData icon;
  final String? userEmail;
  final String? userAuthToken;
  final bool initialJoined;
  final int initialMemberCount;
  final double initialAverageRating;
  final void Function(bool joined, int memberCount)? onMembershipChanged;
  final void Function(double averageRating)? onAverageRatingChanged;

  const SocietyDetailsPage({
    super.key,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.icon,
    this.userEmail,
    this.userAuthToken,
    this.initialJoined = false,
    this.initialMemberCount = 0,
    this.initialAverageRating = 0,
    this.onMembershipChanged,
    this.onAverageRatingChanged,
  });

  @override
  State<SocietyDetailsPage> createState() => _SocietyDetailsPageState();
}

class _SocietyDetailsPageState extends State<SocietyDetailsPage> {
  final SocietyService _societyService = SocietyService();
  final TextEditingController _reviewName = TextEditingController();
  final TextEditingController _reviewComment = TextEditingController();
  final int _reviewCommentMaxLength = 500;

  bool _joined = false;
  bool _loadingReviews = false;
  bool _isAdminViewer = false;
  bool _canCreateReview = false;
  String? _reviewBlockReason;
  int _rating = 5;
  int _memberCount = 0;
  double _averageRating = 0;
  ReviewSortOption _reviewSort = ReviewSortOption.latest;
  int? _reviewMinRating;
  List<SocietyReview> _reviews = [];

  @override
  void initState() {
    super.initState();
    _joined = widget.initialJoined;
    _memberCount = widget.initialMemberCount;
    _averageRating = widget.initialAverageRating;
    _loadReviews();
    _checkMembership();
  }

  @override
  void dispose() {
    _reviewName.dispose();
    _reviewComment.dispose();
    super.dispose();
  }

  Future<void> _checkMembership() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    final result = await _societyService.getMySocieties(email: email);
    if (!mounted || result['success'] != true) return;

    final List<String> names =
        (result['societies'] as List<String>? ?? <String>[]);
    final bool joined = names.contains(widget.name);
    if (joined == _joined) return;

    setState(() {
      _joined = joined;
    });
    widget.onMembershipChanged?.call(_joined, _memberCount);
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loadingReviews = true;
    });

    final result = await _societyService.getReviews(
      societyName: widget.name,
      viewerEmail: widget.userEmail,
      authToken: widget.userAuthToken,
      sort: switch (_reviewSort) {
        ReviewSortOption.latest => 'latest',
        ReviewSortOption.rating => 'rating',
        ReviewSortOption.popularity => 'popularity',
      },
      minRating: _reviewMinRating,
    );
    if (!mounted) return;

    // Prefer backend reviews; fall back to seeded mock reviews when empty/unavailable
    final List<dynamic> rawFromBackend = (result['success'] == true)
        ? (result['reviews'] as List<dynamic>? ?? [])
        : [];

    List<Map<String, dynamic>> rawMaps = rawFromBackend
        .map((e) => e as Map<String, dynamic>)
        .toList(growable: true);

    if (rawMaps.isEmpty) {
      final seeded = _seededReviewsData[widget.name];
      if (seeded != null && seeded.isNotEmpty) {
        rawMaps = List<Map<String, dynamic>>.from(seeded);
      }
    }

    if (rawMaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not load reviews.',
          ),
        ),
      );
    }

    final List<SocietyReview> reviews = rawMaps
        .map(
          (m) => SocietyReview(
            id: (m['id'] as int?) ?? 0,
            author: (m['author'] as String?) ?? 'Anonymous',
            authorDisplayName:
                (m['author_display_name'] as String?) ?? 'Anonymous',
            rating: (m['rating'] as int?) ?? 5,
            comment: (m['comment'] as String?) ?? '',
            likes: (m['likes'] as int?) ?? 0,
            dislikes: (m['dislikes'] as int?) ?? 0,
            userReaction: m['user_reaction'] as String?,
            canReact: m['can_react'] == true,
            adminResponseText:
                (m['admin_response'] as Map<String, dynamic>?)?['text']
                    as String?,
            adminResponderName:
                (m['admin_response']
                        as Map<String, dynamic>?)?['admin_display_name']
                    as String?,
          ),
        )
        .toList();

    final double average = reviews.isEmpty
        ? _averageRating
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

    setState(() {
      _reviews = reviews;
      _averageRating = average;
      _isAdminViewer = result['viewer_is_admin'] == true;
      _canCreateReview = result['can_create_review'] == true;
      _reviewBlockReason = result['review_block_reason']?.toString();
    });
    widget.onAverageRatingChanged?.call(_averageRating);

    if (mounted) {
      setState(() {
        _loadingReviews = false;
      });
    }
  }

  Future<void> _reactToReview({
    required SocietyReview review,
    required String reactionType,
  }) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before reacting.')),
      );
      return;
    }

    final result = await _societyService.reactToReview(
      email: email,
      reviewId: review.id,
      reactionType: reactionType,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _reviews = _reviews.map((item) {
          if (item.id != review.id) return item;
          return item.copyWith(
            likes: (result['likes'] as int?) ?? item.likes,
            dislikes: (result['dislikes'] as int?) ?? item.dislikes,
            userReaction: result['user_reaction']?.toString(),
            canReact: true,
          );
        }).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not react to review.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteReviewAsAdmin(SocietyReview review) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This will permanently remove the review.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _societyService.deleteReviewAsAdmin(
      adminEmail: email,
      reviewId: review.id,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Review deleted.'),
        ),
      );
      await _loadReviews();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not delete review.',
          ),
        ),
      );
    }
  }

  Future<void> _respondToReviewAsAdmin(SocietyReview review) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    final controller = TextEditingController();
    final responseText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to review'),
        content: TextField(
          controller: controller,
          maxLength: _reviewCommentMaxLength,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write admin response',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (responseText == null || responseText.isEmpty) return;

    final result = await _societyService.respondToReviewAsAdmin(
      adminEmail: email,
      reviewId: review.id,
      responseText: responseText,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Response saved.'),
        ),
      );
      await _loadReviews();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not save response.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleJoin() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before joining.')),
      );
      return;
    }

    if (!_joined) {
      final result = await _societyService.joinSociety(
        email: email,
        societyName: widget.name,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _joined = true;
          _memberCount = _memberCount + 1;
        });
        widget.onMembershipChanged?.call(_joined, _memberCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Joined ${widget.name}.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Could not join society.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _joined = false;
      _memberCount = (_memberCount - 1).clamp(0, 1000000);
    });
    widget.onMembershipChanged?.call(_joined, _memberCount);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('You left ${widget.name}.')));
  }

  Future<void> _submitReview() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to write a review.')),
      );
      return;
    }

    if (!_joined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to join this society before reviewing.'),
        ),
      );
      return;
    }

    if (!_canCreateReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _reviewBlockReason ?? 'You cannot create a review right now.',
          ),
        ),
      );
      return;
    }

    final String comment = _reviewComment.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a review comment.')),
      );
      return;
    }

    if (comment.length > _reviewCommentMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Review comment must be $_reviewCommentMaxLength characters or less.',
          ),
        ),
      );
      return;
    }

    final result = await _societyService.submitReview(
      email: email,
      societyName: widget.name,
      rating: _rating,
      comment: comment,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _reviewName.clear();
      _reviewComment.clear();
      setState(() {
        _rating = 5;
      });
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Review sent.'),
        ),
      );

      await _loadReviews();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not submit review.',
          ),
        ),
      );
    }
  }

  void _openNotificationsPage() {
    if (!_joined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join this society to view Events & Polls.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocietyNotificationsPage(
          societyName: widget.name,
          societyIcon: widget.icon,
          userEmail: widget.userEmail,
          userAuthToken: widget.userAuthToken,
        ),
      ),
    );
  }

  void _openMembersPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MembersPage(societyName: widget.name, userEmail: widget.userEmail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  child: Icon(widget.icon, size: 80, color: Colors.white),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(widget.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _DetailStat(
                              icon: Icons.people,
                              label: 'Members',
                              value: _memberCount.toString(),
                            ),
                          ),
                          Expanded(
                            child: _DetailStat(
                              icon: Icons.star,
                              label: 'Average rating',
                              value: _averageRating.toStringAsFixed(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _toggleJoin,
                    icon: Icon(_joined ? Icons.exit_to_app : Icons.group_add),
                    label: Text(_joined ? 'Leave society' : 'Join society'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _joined
                          ? Colors.orange
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _joined ? _openNotificationsPage : null,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Events & Polls'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openMembersPage,
                    icon: const Icon(Icons.group),
                    label: const Text('Members'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Reviews',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<ReviewSortOption>(
                          initialValue: _reviewSort,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Sort',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ReviewSortOption.latest,
                              child: Text('Latest'),
                            ),
                            DropdownMenuItem(
                              value: ReviewSortOption.rating,
                              child: Text('Rating'),
                            ),
                            DropdownMenuItem(
                              value: ReviewSortOption.popularity,
                              child: Text('Popular'),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() {
                              _reviewSort = value;
                            });
                            await _loadReviews();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _reviewMinRating,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All'),
                            ),
                            DropdownMenuItem<int?>(value: 3, child: Text('3+')),
                            DropdownMenuItem<int?>(value: 4, child: Text('4+')),
                            DropdownMenuItem<int?>(value: 5, child: Text('5')),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              _reviewMinRating = value;
                            });
                            await _loadReviews();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingReviews)
                    const Center(child: CircularProgressIndicator())
                  else if (_reviews.isEmpty)
                    Text(
                      'No reviews yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ..._reviews.map(
                      (r) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r.authorDisplayName} (${r.author})',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('${'★' * r.rating}${'☆' * (5 - r.rating)}'),
                              const SizedBox(height: 8),
                              Text(r.comment),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: r.canReact
                                        ? () => _reactToReview(
                                            review: r,
                                            reactionType: 'like',
                                          )
                                        : null,
                                    icon: const Icon(
                                      Icons.thumb_up_alt_outlined,
                                    ),
                                    label: Text('Like (${r.likes})'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: r.canReact
                                        ? () => _reactToReview(
                                            review: r,
                                            reactionType: 'dislike',
                                          )
                                        : null,
                                    icon: const Icon(
                                      Icons.thumb_down_alt_outlined,
                                    ),
                                    label: Text('Dislike (${r.dislikes})'),
                                  ),
                                  if (r.userReaction != null)
                                    Text(
                                      'You reacted: ${r.userReaction}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              if (r.adminResponseText != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Admin response (${r.adminResponderName ?? 'Admin'})',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(r.adminResponseText!),
                                    ],
                                  ),
                                ),
                              ],
                              if (_isAdminViewer) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () =>
                                          _respondToReviewAsAdmin(r),
                                      icon: const Icon(Icons.reply),
                                      label: const Text('Respond'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _deleteReviewAsAdmin(r),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_joined &&
                      widget.userEmail != null &&
                      _canCreateReview) ...[
                    Text(
                      'Write a review',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewName,
                      decoration: const InputDecoration(
                        labelText: 'Name (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _rating,
                      decoration: const InputDecoration(
                        labelText: 'Rating',
                        border: OutlineInputBorder(),
                      ),
                      items: const [1, 2, 3, 4, 5]
                          .map(
                            (v) => DropdownMenuItem<int>(
                              value: v,
                              child: Text('$v / 5'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _rating = v;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reviewComment,
                      maxLength: _reviewCommentMaxLength,
                      decoration: const InputDecoration(
                        labelText: 'Your review',
                        helperText:
                            'Avoid offensive language. One active review allowed.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _submitReview,
                      child: const Text('Submit review'),
                    ),
                  ] else if (_joined && widget.userEmail != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _reviewBlockReason ??
                                  'You cannot create a review right now.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Join this society and log in to write a review.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade700)),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class SocietyNotificationsPage extends StatefulWidget {
  final String societyName;
  final IconData societyIcon;
  final String? userEmail;
  final String? userAuthToken;

  const SocietyNotificationsPage({
    super.key,
    required this.societyName,
    required this.societyIcon,
    this.userEmail,
    this.userAuthToken,
  });

  @override
  State<SocietyNotificationsPage> createState() =>
      _SocietyNotificationsPageState();
}

class _SocietyNotificationsPageState extends State<SocietyNotificationsPage> {
  final SocietyService _societyService = SocietyService();

  bool _loading = true;
  bool _canCreatePoll = false;
  bool _canCreateInfo = false;
  List<_SocietyPoll> _polls = [];
  List<_SocietyInfo> _infoItems = [];
  List<_NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    await Future.wait([_loadPolls(), _loadNotifications()]);
    if (mounted)
      setState(() {
        _loading = false;
      });
  }

  Future<void> _loadPolls() async {
    setState(() {
      _loading = true;
    });

    final result = await _societyService.getPolls(
      societyName: widget.societyName,
      viewerEmail: widget.userEmail,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final List<dynamic> raw = result['polls'] as List<dynamic>? ?? [];
      final List<dynamic> rawInfo =
          result['info_items'] as List<dynamic>? ?? [];
      setState(() {
        _polls =
            raw
                .map((item) => item as Map<String, dynamic>)
                .map(_SocietyPoll.fromJson)
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _infoItems =
            rawInfo
                .map((item) => item as Map<String, dynamic>)
                .map(_SocietyInfo.fromJson)
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _canCreatePoll = result['can_create_poll'] == true;
        _canCreateInfo = result['can_create_info'] == true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not load polls.',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    final result = await _societyService.getNotifications(
      societyName: widget.societyName,
      viewerEmail: widget.userEmail,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final List<dynamic> raw = result['notifications'] as List<dynamic>? ?? [];
      setState(() {
        _notifications = raw
            .map((e) => _NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _voteOnPoll(_SocietyPoll poll, _SocietyPollOption option) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before voting.')),
      );
      return;
    }

    if (poll.viewerVoteOptionId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only vote once per poll.')),
      );
      return;
    }

    final result = await _societyService.votePoll(
      email: email,
      pollId: poll.id,
      optionId: option.id,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Vote recorded.'),
        ),
      );
      await _loadPolls();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not vote on poll.',
          ),
        ),
      );
    }
  }

  Future<void> _showCreatePollDialog() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as an admin to create polls.'),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final optionsController = TextEditingController();
    final durationController = TextEditingController(text: '60');

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Poll title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: optionsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Time limit in hours',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (submit != true) {
      titleController.dispose();
      descriptionController.dispose();
      optionsController.dispose();
      durationController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final options = optionsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final durationHours = int.tryParse(durationController.text.trim());

    titleController.dispose();
    descriptionController.dispose();
    optionsController.dispose();
    durationController.dispose();

    if (title.isEmpty ||
        options.length < 2 ||
        durationHours == null ||
        durationHours < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter title, at least 2 options, and a valid time limit.',
          ),
        ),
      );
      return;
    }

    final result = await _societyService.createPoll(
      adminEmail: email,
      societyName: widget.societyName,
      title: title,
      description: description,
      options: options,
      durationHours: durationHours,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Poll created.'),
        ),
      );
      await _loadPolls();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not create poll.',
          ),
        ),
      );
    }
  }

  Future<void> _showCreateInfoDialog() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as an admin to add information.'),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Information',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (submit != true) {
      titleController.dispose();
      contentController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final content = contentController.text.trim();

    titleController.dispose();
    contentController.dispose();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter information text before posting.')),
      );
      return;
    }

    final result = await _societyService.createInfo(
      adminEmail: email,
      societyName: widget.societyName,
      title: title,
      content: content,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Information posted.'),
        ),
      );
      await _loadPolls();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not post information.',
          ),
        ),
      );
    }
  }

  String _timestampLabel(DateTime timestamp) {
    final local = timestamp.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yy = (local.year % 100).toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy\n$hh:$min';
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return monthKey;
    }

    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[month - 1]} $year';
  }

  Future<void> _showReviewAnalyticsDialog() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as an admin to view analytics.'),
        ),
      );
      return;
    }

    final result = await _societyService.getReviewAnalytics(
      societyName: widget.societyName,
      viewerEmail: email,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not load analytics.',
          ),
        ),
      );
      return;
    }

    // Get stats from response
    final stats = result['stats'] as Map<String, dynamic>? ?? {};
    final int totalMembers = stats['total_members'] as int? ?? 0;
    final int adminCount = stats['admin_count'] as int? ?? 0;
    final int totalAnnouncements = stats['total_announcements'] as int? ?? 0;
    final int totalPolls = stats['total_polls'] as int? ?? 0;
    final int totalReviews = stats['total_reviews'] as int? ?? 0;
    final int totalReactions = stats['total_reactions'] as int? ?? 0;

    final List<Map<String, dynamic>> trends =
      (result['trends'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${widget.societyName} Analytics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Member Statistics
                _buildStatCard(
                  context,
                  title: 'Members',
                  stats: [
                    _StatItem('Current Members', '$totalMembers', Icons.people),
                    _StatItem(
                      'Current Admins',
                      '$adminCount',
                      Icons.admin_panel_settings,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Activity Statistics
                _buildStatCard(
                  context,
                  title: 'Activity (All Time)',
                  stats: [
                    _StatItem(
                      'Announcements',
                      '$totalAnnouncements',
                      Icons.announcement,
                    ),
                    _StatItem('Polls', '$totalPolls', Icons.poll),
                    _StatItem('Reviews', '$totalReviews', Icons.rate_review),
                    _StatItem('Reactions', '$totalReactions', Icons.favorite),
                  ],
                ),

                const SizedBox(height: 16),
                Text(
                  'Trends',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Members and reviews over time',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: trends.isEmpty
                              ? null
                              : () => _showMembersReviewsTrendDialog(
                                    context: context,
                                    rawTrends: trends,
                                  ),
                          icon: const Icon(Icons.show_chart),
                          label: const Text('View line graph'),
                        ),
                        if (trends.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'No trend data available yet.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<_TrendPoint> _parseTrendPoints(List<Map<String, dynamic>> rawTrends) {
    final points = <_TrendPoint>[];

    for (final row in rawTrends) {
      final monthKey = row['month']?.toString() ?? '';
      final parts = monthKey.split('-');
      if (parts.length != 2) continue;

      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null || month < 1 || month > 12) continue;

      final members = (row['member_count'] as int?) ?? 0;
      final reviews = (row['review_count'] as int?) ?? 0;

      points.add(
        _TrendPoint(
          month: DateTime(year, month),
          memberCount: members,
          reviewCount: reviews,
        ),
      );
    }

    points.sort((a, b) => a.month.compareTo(b.month));
    return points;
  }

  Future<void> _showMembersReviewsTrendDialog({
    required BuildContext context,
    required List<Map<String, dynamic>> rawTrends,
  }) async {
    final points = _parseTrendPoints(rawTrends);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Members & Reviews over time',
          style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
        ),
        content: SizedBox(
          width: 720,
          child: points.isEmpty
              ? const Text('No trend data available yet.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MembersReviewsLegend(
                      membersColor:
                          Theme.of(dialogContext).colorScheme.primary,
                      reviewsColor:
                          Theme.of(dialogContext).colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: _MembersReviewsLineChart(
                        points: points,
                        axisColor:
                            Theme.of(dialogContext).colorScheme.outline,
                        membersColor:
                            Theme.of(dialogContext).colorScheme.primary,
                        reviewsColor:
                            Theme.of(dialogContext).colorScheme.secondary,
                        labelStyle: Theme.of(dialogContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  Theme.of(dialogContext).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required List<_StatItem> stats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 32,
              runSpacing: 16,
              children: stats
                  .map((item) => _buildStatItem(context, item))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, _StatItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            item.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddOptionDialog(_SocietyPoll poll) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    final controller = TextEditingController();
    final String? optionText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add poll option'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Option text',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (optionText == null || optionText.isEmpty) return;

    final result = await _societyService.editPoll(
      adminEmail: email,
      pollId: poll.id,
      action: 'add_option',
      optionText: optionText,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? 'Poll updated.')),
    );
    if (result['success'] == true) {
      await _loadPolls();
    }
  }

  Future<void> _showDeleteOptionDialog(_SocietyPoll poll) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    if (poll.options.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poll must keep at least 2 options.')),
      );
      return;
    }

    final int? optionId = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Delete which option?'),
        children: poll.options
            .map(
              (option) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(option.id),
                child: Text('${option.text} (${option.votes})'),
              ),
            )
            .toList(),
      ),
    );

    if (optionId == null) return;

    final result = await _societyService.editPoll(
      adminEmail: email,
      pollId: poll.id,
      action: 'delete_option',
      optionId: optionId,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? 'Poll updated.')),
    );
    if (result['success'] == true) {
      await _loadPolls();
    }
  }

  Future<void> _deletePoll(_SocietyPoll poll) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete poll?'),
        content: const Text('This will permanently delete this poll.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _societyService.deletePoll(
      adminEmail: email,
      pollId: poll.id,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? 'Poll deleted.')),
    );
    if (result['success'] == true) {
      await _loadPolls();
    }
  }

  Future<void> _deleteInfo(_SocietyInfo info) async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will permanently delete this message.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _societyService.deleteInfo(
      adminEmail: email,
      infoId: info.id,
      authToken: widget.userAuthToken,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Message deleted.'),
      ),
    );
    if (result['success'] == true) {
      await _loadPolls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.societyName} Events & Polls'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          if (_canCreatePoll || _canCreateInfo)
            IconButton(
              tooltip: 'Review analytics',
              onPressed: _showReviewAnalyticsDialog,
              icon: const Icon(Icons.insights_outlined),
            ),
          if (_canCreateInfo)
            IconButton(
              tooltip: 'Add information',
              onPressed: _showCreateInfoDialog,
              icon: const Icon(Icons.post_add_outlined),
            ),
          if (_canCreatePoll)
            IconButton(
              tooltip: 'Create poll',
              onPressed: _showCreatePollDialog,
              icon: const Icon(Icons.add_chart_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPolls,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        widget.societyIcon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.societyName} updates',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_notifications.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._notifications.map(
                        (n) => ListTile(
                          title: Text(
                            n.message,
                            style: TextStyle(
                              fontWeight: n.read
                                  ? FontWeight.normal
                                  : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(_timestampLabel(n.createdAt)),
                          trailing: n.read
                              ? null
                              : TextButton(
                                  onPressed: () async {
                                    final res = await _societyService
                                        .markNotificationRead(
                                          notificationId: n.id,
                                          authToken: widget.userAuthToken,
                                        );
                                    if (res['success'] == true) {
                                      await _loadNotifications();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            res['message'] ?? 'Marked read',
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            res['message'] ??
                                                'Could not mark read',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Mark read'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_infoItems.isEmpty && _polls.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    (_canCreatePoll || _canCreateInfo)
                        ? 'No posts yet. Use the top buttons to add information or a poll.'
                        : 'No posts available right now.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            else
              ..._polls.map(
                (poll) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 74,
                          child: Text(
                            _timestampLabel(poll.createdAt),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      poll.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          poll.isOpen
                                              ? 'Poll Open'
                                              : 'Poll Closed',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (poll.isOpen)
                                        PollCountdown(closesAt: poll.closesAt),
                                    ],
                                  ),
                                  if (_canCreatePoll)
                                    PopupMenuButton<String>(
                                      tooltip: 'Manage poll',
                                      onSelected: (value) async {
                                        if (value == 'add_option') {
                                          await _showAddOptionDialog(poll);
                                        } else if (value == 'delete_option') {
                                          await _showDeleteOptionDialog(poll);
                                        } else if (value == 'delete_poll') {
                                          await _deletePoll(poll);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem<String>(
                                          value: 'add_option',
                                          child: Text('Add option'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete_option',
                                          child: Text('Delete option'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete_poll',
                                          child: Text('Delete poll'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              if (poll.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(poll.description),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Total votes: ${poll.totalVotes}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 10),
                              ...poll.options.map(
                                (option) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        (!poll.isOpen ||
                                            poll.viewerVoteOptionId != null)
                                        ? null
                                        : () => _voteOnPoll(poll, option),
                                    icon: Icon(
                                      poll.viewerVoteOptionId == option.id
                                          ? Icons.check_circle
                                          : Icons.how_to_vote_outlined,
                                    ),
                                    label: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${option.text} (${option.votes})',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (poll.viewerVoteOptionId != null)
                                Text(
                                  'Your vote has been recorded.',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_infoItems.isNotEmpty && _polls.isNotEmpty)
              const SizedBox(height: 6),
            ..._infoItems.map(
              (info) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 74,
                        child: Text(
                          _timestampLabel(info.createdAt),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    info.title.isEmpty ? 'Message' : info.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text('Info'),
                                ),
                                if (_canCreateInfo)
                                  IconButton(
                                    tooltip: 'Delete message',
                                    onPressed: () => _deleteInfo(info),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(info.content),
                            const SizedBox(height: 6),
                            Text(
                              'Posted by ${info.adminDisplayName}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocietyPoll {
  final int id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime closesAt;
  final bool isOpen;
  final int totalVotes;
  final int? viewerVoteOptionId;
  final List<_SocietyPollOption> options;

  const _SocietyPoll({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.closesAt,
    required this.isOpen,
    required this.totalVotes,
    required this.viewerVoteOptionId,
    required this.options,
  });

  factory _SocietyPoll.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return _SocietyPoll(
      id: (json['id'] as int?) ?? 0,
      title: (json['title'] as String?) ?? 'Untitled poll',
      description: (json['description'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      closesAt:
          DateTime.tryParse((json['closes_at'] as String?) ?? '') ??
          DateTime.now(),
      isOpen: json['is_open'] == true,
      totalVotes: (json['total_votes'] as int?) ?? 0,
      viewerVoteOptionId: json['viewer_vote_option_id'] as int?,
      options: rawOptions
          .map((item) => item as Map<String, dynamic>)
          .map(_SocietyPollOption.fromJson)
          .toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(this.label, this.value, this.icon);
}

class _MonthlyReviewTrend {
  final String month;
  final double avgRating;
  final int reviewCount;

  const _MonthlyReviewTrend({
    required this.month,
    required this.avgRating,
    required this.reviewCount,
  });

  factory _MonthlyReviewTrend.fromJson(Map<String, dynamic> json) {
    return _MonthlyReviewTrend(
      month: (json['month'] as String?) ?? '',
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      reviewCount: (json['review_count'] as int?) ?? 0,
    );
  }
}

class _TrendPoint {
  final DateTime month;
  final int memberCount;
  final int reviewCount;

  const _TrendPoint({
    required this.month,
    required this.memberCount,
    required this.reviewCount,
  });
}

class _MembersReviewsLegend extends StatelessWidget {
  final Color membersColor;
  final Color reviewsColor;

  const _MembersReviewsLegend({
    required this.membersColor,
    required this.reviewsColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        _LegendItem(color: membersColor, label: 'Members', style: style),
        const SizedBox(width: 16),
        _LegendItem(color: reviewsColor, label: 'Reviews', style: style),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final TextStyle? style;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: style),
      ],
    );
  }
}

class _MembersReviewsLineChart extends StatelessWidget {
  final List<_TrendPoint> points;
  final Color axisColor;
  final Color membersColor;
  final Color reviewsColor;
  final TextStyle? labelStyle;

  const _MembersReviewsLineChart({
    required this.points,
    required this.axisColor,
    required this.membersColor,
    required this.reviewsColor,
    required this.labelStyle,
  });

  String _labelForMonth(DateTime date) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final idx = date.month - 1;
    if (idx < 0 || idx >= names.length) return '${date.month}/${date.year}';
    return '${names[idx]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final labels = points.map((p) => _labelForMonth(p.month)).toList();
    return CustomPaint(
      painter: _MembersReviewsLineChartPainter(
        points: points,
        labels: labels,
        axisColor: axisColor,
        membersColor: membersColor,
        reviewsColor: reviewsColor,
        labelStyle: labelStyle ?? Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _MembersReviewsLineChartPainter extends CustomPainter {
  final List<_TrendPoint> points;
  final List<String> labels;
  final Color axisColor;
  final Color membersColor;
  final Color reviewsColor;
  final TextStyle? labelStyle;

  const _MembersReviewsLineChartPainter({
    required this.points,
    required this.labels,
    required this.axisColor,
    required this.membersColor,
    required this.reviewsColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    const leftPadding = 46.0;
    const rightPadding = 16.0;
    const topPadding = 16.0;
    const bottomPadding = 36.0;

    final plotWidth = size.width - leftPadding - rightPadding;
    final plotHeight = size.height - topPadding - bottomPadding;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final plotRect = Rect.fromLTWH(leftPadding, topPadding, plotWidth, plotHeight);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Axes
    canvas.drawLine(plotRect.bottomLeft, plotRect.bottomRight, axisPaint);
    canvas.drawLine(plotRect.bottomLeft, plotRect.topLeft, axisPaint);

    // Determine y max
    var yMax = 0;
    for (final p in points) {
      if (p.memberCount > yMax) yMax = p.memberCount;
      if (p.reviewCount > yMax) yMax = p.reviewCount;
    }
    if (yMax <= 0) yMax = 1;

    final dx = points.length == 1 ? 0.0 : plotRect.width / (points.length - 1);

    Offset pointOffset(int i, int value) {
      final x = plotRect.left + dx * i;
      final y = plotRect.bottom - (value / yMax) * plotRect.height;
      return Offset(x, y);
    }

    void drawSeries({required Color color, required int Function(_TrendPoint) valueOf}) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke;

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final v = valueOf(points[i]);
        final o = pointOffset(i, v);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, linePaint);

      for (var i = 0; i < points.length; i++) {
        final v = valueOf(points[i]);
        final o = pointOffset(i, v);
        canvas.drawCircle(o, 3.2, dotPaint);
      }
    }

    // Series: members + reviews
    drawSeries(color: membersColor, valueOf: (p) => p.memberCount);
    drawSeries(color: reviewsColor, valueOf: (p) => p.reviewCount);

    // Y labels (0 and max)
    final yLabelStyle = labelStyle;
    void paintText(String text, Offset offset) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: yLabelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      tp.paint(canvas, offset);
    }

    paintText('0', Offset(plotRect.left - 18, plotRect.bottom - 8));
    paintText('$yMax', Offset(plotRect.left - 34, plotRect.top - 8));

    // X labels
    final labelStep = points.length <= 6 ? 1 : ((points.length / 6).ceil());
    for (var i = 0; i < labels.length; i += labelStep) {
      final label = labels[i];
      final x = plotRect.left + dx * i;
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final offset = Offset(x - tp.width / 2, plotRect.bottom + 6);
      tp.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _MembersReviewsLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.membersColor != membersColor ||
        oldDelegate.reviewsColor != reviewsColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.labels != labels;
  }
}

class PollCountdown extends StatefulWidget {
  final DateTime closesAt;

  const PollCountdown({super.key, required this.closesAt});

  @override
  State<PollCountdown> createState() => _PollCountdownState();
}

class _PollCountdownState extends State<PollCountdown> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _updateRemaining() {
    final now = DateTime.now().toUtc();
    final closes = widget.closesAt.toUtc();
    _remaining = closes.difference(now);
    if (_remaining.isNegative) _remaining = Duration.zero;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _updateRemaining();
    });
    if (_remaining == Duration.zero) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${mm}:${ss}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _remaining == Duration.zero ? 'Ended' : 'Ends in ${_format(_remaining)}',
      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
    );
  }
}

class _SocietyPollOption {
  final int id;
  final String text;
  final int votes;

  const _SocietyPollOption({
    required this.id,
    required this.text,
    required this.votes,
  });

  factory _SocietyPollOption.fromJson(Map<String, dynamic> json) {
    return _SocietyPollOption(
      id: (json['id'] as int?) ?? 0,
      text: (json['text'] as String?) ?? '',
      votes: (json['votes'] as int?) ?? 0,
    );
  }
}

class _SocietyInfo {
  final int id;
  final String title;
  final String content;
  final String adminDisplayName;
  final DateTime createdAt;

  const _SocietyInfo({
    required this.id,
    required this.title,
    required this.content,
    required this.adminDisplayName,
    required this.createdAt,
  });

  factory _SocietyInfo.fromJson(Map<String, dynamic> json) {
    return _SocietyInfo(
      id: (json['id'] as int?) ?? 0,
      title: (json['title'] as String?) ?? 'Information',
      content: (json['content'] as String?) ?? '',
      adminDisplayName: (json['admin_display_name'] as String?) ?? 'Admin',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class _NotificationItem {
  final int id;
  final String type;
  final String message;
  final String link;
  final DateTime createdAt;
  final bool read;

  const _NotificationItem({
    required this.id,
    required this.type,
    required this.message,
    required this.link,
    required this.createdAt,
    required this.read,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    return _NotificationItem(
      id: (json['id'] as int?) ?? 0,
      type: (json['type'] as String?) ?? 'info',
      message: (json['message'] as String?) ?? '',
      link: (json['link'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      read: (json['read'] as bool?) ?? false,
    );
  }
}
