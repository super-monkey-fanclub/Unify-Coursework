import 'package:flutter/material.dart';
import 'dart:async';
import 'profile.dart';
import 'socieites.dart';
import 'about_us.dart'; // Add this import

void main() {
  runApp(const UnifyApp());
}

class UnifyApp extends StatelessWidget {
  const UnifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unify - University of Portsmouth Societies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003087), // UoP Blue
          primary: const Color(0xFF003087), // UoP Blue
          secondary: const Color(0xFF7B2D8E), // UoP Purple
        ),
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<String> _placeholderItems = [
    'Art Society',
    'Anime Society',
    'Gaming Society',
    'Music Society',
    'Photography Club',
  ];
  late List<String> _filteredItems;
  bool _showHeaderSearch = false;

  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(_placeholderItems);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_placeholderItems);
      } else {
        _filteredItems = _placeholderItems
            .where((s) => s.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleHeaderSearch() {
    setState(() {
      _showHeaderSearch = !_showHeaderSearch;
      if (!_showHeaderSearch) {
        _searchController.clear();
      }
    });
    if (_showHeaderSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _handleAuthResult(dynamic value) {
    if (!mounted || value == null) return;

    if (value is Map<String, dynamic> && value['__logout__'] == true) {
      setState(() {
        _currentUser = null;
      });
    } else if (value is Map<String, dynamic>) {
      setState(() {
        _currentUser = value;
      });
    }
  }

  void _openAuthPage() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => AuthPage(currentUser: _currentUser),
          ),
        )
        .then(_handleAuthResult);
  }

  void _openAboutUsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutUsPage()));
  }

  void _openSocietiesPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocietiesPage(
          userEmail: _currentUser != null
              ? _currentUser!['email'] as String?
              : null,
        ),
      ),
    );
  }

  void _openSearchResultsPage([String? query]) {
    final searchQuery = query ?? _searchController.text;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SearchResultsPage(query: searchQuery, items: _placeholderItems),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Row(
          children: const [
            Text(
              'Unify',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _HeaderStatChip(icon: Icons.explore, label: '9+ societies'),
                    SizedBox(width: 6),
                    _HeaderStatChip(
                      icon: Icons.people_alt,
                      label: 'Student led',
                    ),
                    SizedBox(width: 6),
                    _HeaderStatChip(icon: Icons.star, label: 'Top rated'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: _toggleHeaderSearch,
            icon: Icon(
              _showHeaderSearch ? Icons.close : Icons.search,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: _openAuthPage,
            icon: const Icon(Icons.person, color: Colors.white),
          ),
          TextButton(
            onPressed: _openAboutUsPage,
            child: const Text(
              'About Us',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showHeaderSearch ? 72 : 0),
          child: _showHeaderSearch
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _openSearchResultsPage,
                    decoration: InputDecoration(
                      hintText: 'Search societies, e.g. "Art", "Gaming"',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _openSearchResultsPage,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome${_currentUser == null ? '' : ', ${_currentUser!['name'] ?? 'back'}'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find societies that match your interests and connect with students faster.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _openSocietiesPage,
                  icon: const Icon(Icons.groups),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  label: const Text('Find societies'),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Featured this week',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Explore popular student groups on campus',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 350, child: HeroCarousel()),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _openAuthPage,
                  icon: const Icon(Icons.login),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  label: const Text('Join a society today'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Text(
          'No results',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.groups)),
          title: Text(item),
          subtitle: const Text('Placeholder description'),
          onTap: () {
            // Placeholder: navigate to society details
          },
        );
      },
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroStatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderStatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Society> _societies = [
    Society(
      name: 'Art Society',
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&auto=format&fit=crop',
    ),
    Society(
      name: 'Anime Society',
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&auto=format&fit=crop',
    ),
    Society(
      name: 'Gaming Society',
      rating: 4.9,
      imageUrl:
          'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _societies.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _societies.length,
            itemBuilder: (context, index) {
              return SocietyCard(society: _societies[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _societies.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SocietyCard extends StatelessWidget {
  final Society society;

  const SocietyCard({super.key, required this.society});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              society.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Theme.of(context).colorScheme.primary),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    society.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        society.rating.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
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

class Society {
  final String name;
  final double rating;
  final String imageUrl;

  Society({required this.name, required this.rating, required this.imageUrl});
}

class SearchResultsPage extends StatefulWidget {
  final String query;
  final List<String> items;

  const SearchResultsPage({
    super.key,
    required this.query,
    required this.items,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late List<String> _results;

  @override
  void initState() {
    super.initState();
    final q = widget.query.toLowerCase();
    if (q.isEmpty) {
      _results = List.from(widget.items);
    } else {
      _results = widget.items
          .where((i) => i.toLowerCase().contains(q))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search: "${widget.query}"'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(
                'No results for "${widget.query}"',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12.0),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.groups)),
                  title: Text(item),
                  subtitle: const Text('Placeholder description'),
                  onTap: () {
                    // Placeholder: navigate to details
                  },
                );
              },
            ),
    );
  }
}
