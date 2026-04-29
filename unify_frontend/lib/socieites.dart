import 'package:flutter/material.dart';

import 'services/society_service.dart';

class SocietiesPage extends StatefulWidget {
  final String? userEmail;

  const SocietiesPage({super.key, this.userEmail});

  @override
  State<SocietiesPage> createState() => _SocietiesPageState();
}

class _SocietiesPageState extends State<SocietiesPage> {
  final TextEditingController _searchController = TextEditingController();
  final SocietyService _societyService = SocietyService();
  final List<String> _allSocieties = [
    'Art Society',
    'Anime Society',
    'Gaming Society',
    'Music Society',
    'Photography Club',
    'Dance Society',
    'Drama Club',
    'Coding Society',
    'Robotics Club',
  ];
  final Map<String, String> _descriptions = const {
    'Art Society':
        'A friendly society for drawing, painting, and creative workshops.',
    'Anime Society': 'Weekly anime screenings and socials for all fans.',
    'Gaming Society':
        'Casual and competitive gaming events across many genres.',
    'Music Society': 'Jam sessions, open mics, and opportunities to perform.',
    'Photography Club': 'Photo walks, editing tips, and portfolio feedback.',
    'Dance Society':
        'Learn routines and perform at events throughout the year.',
    'Drama Club': 'Acting workshops, productions, and backstage roles.',
    'Coding Society': 'Hack nights, project teams, and interview practice.',
    'Robotics Club': 'Build, program, and compete with robotics projects.',
  };

  // Unsplash images relevant to each society
  final Map<String, String> _images = const {
    'Art Society':
        'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&auto=format&fit=crop',
    'Anime Society':
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&auto=format&fit=crop',
    'Gaming Society':
        'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop',
    'Music Society':
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop',
    'Photography Club':
        'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800&auto=format&fit=crop',
    'Dance Society':
        'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop',
    'Drama Club':
        'https://images.unsplash.com/photo-1503095396549-807759245b35?w=800&auto=format&fit=crop',
    'Coding Society':
        'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=800&auto=format&fit=crop',
    'Robotics Club':
        'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&auto=format&fit=crop',
  };

  // Default fallback image if society not found in map
  static const String _fallbackImage =
      'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800&auto=format&fit=crop';

  // Fallback icons per society
  final Map<String, IconData> _icons = const {
    'Art Society': Icons.palette,
    'Anime Society': Icons.tv,
    'Gaming Society': Icons.sports_esports,
    'Music Society': Icons.music_note,
    'Photography Club': Icons.camera_alt,
    'Dance Society': Icons.music_video,
    'Drama Club': Icons.theater_comedy,
    'Coding Society': Icons.code,
    'Robotics Club': Icons.precision_manufacturing,
  };

  late List<String> _filtered;
  List<String> _mySocieties = [];
  bool _showMySocieties = false;
  bool _loadingMySocieties = false;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(_allSocieties);
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    final source = _showMySocieties ? _mySocieties : _allSocieties;
    setState(() {
      if (q.isEmpty) {
		_filtered = List.from(source);
      } else {
		_filtered = source
            .where((s) => s.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _loadMySocieties() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to see My societies.')),
      );
      return;
    }

    setState(() {
      _loadingMySocieties = true;
    });

    final result = await _societyService.getMySocieties(email: email);

    if (!mounted) return;

    if (result['success'] == true) {
      final List<String> names =
          (result['societies'] as List<String>? ?? <String>[]);
      setState(() {
        _mySocieties = names;
        _showMySocieties = true;
      });
      _onSearch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Could not load My societies.',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _loadingMySocieties = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search societies',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _filtered = List.from(_allSocieties);
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('All societies'),
                      selected: !_showMySocieties,
                      onSelected: (selected) {
                        if (!selected) return;
                        setState(() {
                          _showMySocieties = false;
                        });
                        _onSearch();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        _loadingMySocieties ? 'My societies…' : 'My societies',
                      ),
                      selected: _showMySocieties,
                      onSelected: (selected) {
                        if (!selected) return;
                        _loadMySocieties();
                      },
                    ),
                  ],
                ),
                if (_searchController.text.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: _filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                'No matches',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final name = _filtered[index];
                                // Use null-safe lookup with fallback
                                final imageUrl =
                                    _images[name] ?? _fallbackImage;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: NetworkImage(imageUrl),
                                    onBackgroundImageError: (_, __) {},
                                    child: Icon(_icons[name] ?? Icons.groups),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(
                                    _descriptions[name] ??
                                        'Description coming soon.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _searchController.text = name;
                                      _filtered = [name];
                                      FocusScope.of(context).unfocus();
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final name = _filtered[index];
                // Use null-safe lookup with fallback
                final imageUrl = _images[name] ?? _fallbackImage;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SocietyDetailsPage(
                            name: name,
                            description:
                                _descriptions[name] ??
                                'Description coming soon.',
                            imageUrl: imageUrl,
                            icon: _icons[name] ?? Icons.groups,
                            userEmail: widget.userEmail,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Society banner image
                        SizedBox(
                          height: 140,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.15),
                              child: Icon(
                                _icons[name] ?? Icons.groups,
                                size: 60,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Icon(
                                  _icons[name] ?? Icons.groups,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _descriptions[name] ??
                                          'Description coming soon.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
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

class SocietyReview {
  final String author;
  final int rating;
  final String comment;

  const SocietyReview({
    required this.author,
    required this.rating,
    required this.comment,
  });
}

class SocietyDetailsPage extends StatefulWidget {
  final String name;
  final String description;
  final String imageUrl;
  final IconData icon;
  final String? userEmail;

  const SocietyDetailsPage({
    super.key,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.icon,
    this.userEmail,
  });

  @override
  State<SocietyDetailsPage> createState() => _SocietyDetailsPageState();
}

class _SocietyDetailsPageState extends State<SocietyDetailsPage> {
  bool _joined = false;

  final SocietyService _societyService = SocietyService();

  final TextEditingController _reviewName = TextEditingController();
  final TextEditingController _reviewComment = TextEditingController();
  int _rating = 5;
  List<SocietyReview> _reviews = [];
  bool _loadingReviews = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkMembership();
  }

  @override
  void dispose() {
    _reviewName.dispose();
    _reviewComment.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
  setState(() {
    _loadingReviews = true;
  });

  final result = await _societyService.getReviews(societyName: widget.name);

  if (!mounted) return;

  if (result['success'] == true) {
    final List<dynamic> raw = result['reviews'] as List<dynamic>? ?? [];
    setState(() {
    _reviews = raw
      .map((e) => e as Map<String, dynamic>)
      .map(
        (m) => SocietyReview(
        author: (m['author'] as String?) ?? 'Anonymous',
        rating: (m['rating'] as int?) ?? 5,
        comment: (m['comment'] as String?) ?? '',
        ),
      )
      .toList();
    });
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

  Future<void> _checkMembership() async {
    final email = widget.userEmail;
    if (email == null || email.isEmpty) return;

    final result = await _societyService.getMySocieties(email: email);
    if (!mounted || result['success'] != true) return;

    final List<String> names =
        (result['societies'] as List<String>? ?? <String>[]);

    setState(() {
      _joined = names.contains(widget.name);
    });
  }

  Future<void> _toggleJoin() async {
    // Require a logged-in user (email) to join.
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
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String)),
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
    } else {
      // For now, just toggle locally; a leave endpoint could be added later.
      setState(() {
        _joined = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Left ${widget.name}')), 
      );
    }
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

  final author = _reviewName.text.trim().isEmpty
    ? email
    : _reviewName.text.trim();
  final comment = _reviewComment.text.trim();

  if (comment.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please enter a review comment')),
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
    SnackBar(content: Text(result['message'] as String)),
    );

    // Refresh from backend so list matches server.
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
          // Hero image in a collapsible app bar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.name),
              background: Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  child: Icon(widget.icon, size: 80, color: Colors.white),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.2),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Society icon + name header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        child: Icon(widget.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _toggleJoin,
                    icon: Icon(_joined ? Icons.check : Icons.add),
                    label: Text(_joined ? 'Joined' : 'Join society'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _joined
                          ? Colors.green
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
                        child: ListTile(
                          title: Text(
                            '${r.author} • ${'★' * r.rating}${'☆' * (5 - r.rating)}',
                          ),
                          subtitle: Text(r.comment),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_joined && widget.userEmail != null) ...[
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
                      value: _rating,
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
                        setState(() => _rating = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reviewComment,
                      decoration: const InputDecoration(
                        labelText: 'Your review',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _submitReview,
                      child: const Text('Submit review'),
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
