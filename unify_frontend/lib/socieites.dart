import 'package:flutter/material.dart';

import 'services/society_service.dart';

enum SocietySortOption {
  alphabeticalAsc,
  alphabeticalDesc,
  memberCountHighLow,
  ratingHighLow,
}

enum SocietyRatingFilter { any, atLeastThree, atLeastFour }

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

  const SocietiesPage({super.key, this.userEmail});

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
        averageRating: 4.6,
      ),
      SocietySummary(
        name: 'Anime Society',
        description: 'Weekly anime screenings and socials for all fans.',
        category: 'Culture',
        imageUrl:
            'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&auto=format&fit=crop',
        icon: Icons.tv,
        memberCount: 101,
        averageRating: 4.2,
      ),
      SocietySummary(
        name: 'Gaming Society',
        description: 'Casual and competitive gaming events across many genres.',
        category: 'Technology',
        imageUrl:
            'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop',
        icon: Icons.sports_esports,
        memberCount: 174,
        averageRating: 4.8,
      ),
      SocietySummary(
        name: 'Music Society',
        description: 'Jam sessions, open mics, and opportunities to perform.',
        category: 'Creative',
        imageUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop',
        icon: Icons.music_note,
        memberCount: 93,
        averageRating: 4.4,
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
            'https://images.unsplash.com/photo-1503095396549-807759245b35?w=800&auto=format&fit=crop',
        icon: Icons.theater_comedy,
        memberCount: 59,
        averageRating: 3.9,
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
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    itemCount: _filteredSocieties.length,
                    itemBuilder: (context, index) {
                      final society = _filteredSocieties[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
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
                                  initialJoined: society.joined,
                                  initialMemberCount: society.memberCount,
                                  initialAverageRating: society.averageRating,
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
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            society.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        if (society.joined)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Joined',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                                fontWeight: FontWeight.w600,
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

class SocietyDetailsPage extends StatefulWidget {
  final String name;
  final String description;
  final String imageUrl;
  final IconData icon;
  final String? userEmail;
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
      sort: switch (_reviewSort) {
        ReviewSortOption.latest => 'latest',
        ReviewSortOption.rating => 'rating',
        ReviewSortOption.popularity => 'popularity',
      },
      minRating: _reviewMinRating,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final List<dynamic> raw = result['reviews'] as List<dynamic>? ?? [];
      final List<SocietyReview> reviews = raw
          .map((e) => e as Map<String, dynamic>)
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
          : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                reviews.length;

      setState(() {
        _reviews = reviews;
        _averageRating = average;
        _isAdminViewer = result['viewer_is_admin'] == true;
        _canCreateReview = result['can_create_review'] == true;
        _reviewBlockReason = result['review_block_reason']?.toString();
      });
      widget.onAverageRatingChanged?.call(_averageRating);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not load reviews.',
          ),
        ),
      );
    }

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

    if (!review.canReact) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reaction already used for this review.')),
      );
      return;
    }

    final result = await _societyService.reactToReview(
      email: email,
      reviewId: review.id,
      reactionType: reactionType,
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
            canReact: false,
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
              title: Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
