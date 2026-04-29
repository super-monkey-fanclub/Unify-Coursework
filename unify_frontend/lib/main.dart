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
  final List<String> _placeholderItems = [
    'Art Society',
    'Anime Society',
    'Gaming Society',
    'Music Society',
    'Photography Club',
  ];
  late List<String> _filteredItems;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          'Unify',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => AuthPage(currentUser: _currentUser),
                    ),
                  )
                  .then((value) {
                if (!mounted || value == null) return; // back arrow: no change

                if (value is Map<String, dynamic> && value['__logout__'] == true) {
                  // Explicit sign-out
                  setState(() {
                    _currentUser = null;
                  });
                } else if (value is Map<String, dynamic>) {
                  // Logged-in user info
                  setState(() {
                    _currentUser = value;
                  });
                }
              });
            },
            icon: const Icon(Icons.person, color: Colors.white),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AboutUsPage(), // Replace placeholder comment
              ));
            },
            child: const Text(
              'About Us',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SearchResultsPage(
                    query: value,
                    items: _placeholderItems,
                  ),
                ));
              },
              decoration: InputDecoration(
                hintText: 'Search societies, e.g. "Art", "Gaming"',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SearchResultsPage(
                        query: _searchController.text,
                        items: _placeholderItems,
                      ),
                    ));
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          const Expanded(child: HeroCarousel()),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SocietiesPage(
            userEmail: _currentUser != null
              ? _currentUser!['email'] as String?
              : null,
            ),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Find societies'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
          Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => AuthPage(currentUser: _currentUser),
                        ),
                      )
                      .then((value) {
                    if (!mounted || value == null) return; // back arrow: no change

                    if (value is Map<String, dynamic> && value['__logout__'] == true) {
                      setState(() {
                        _currentUser = null;
                      });
                    } else if (value is Map<String, dynamic>) {
                      setState(() {
                        _currentUser = value;
                      });
                    }
                  });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Join a society today'),
                ),
              ],
            ),
          ),
        ],
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
    Society(name: 'Art Society', rating: 4.8),
    Society(name: 'Anime Society', rating: 4.7),
    Society(name: 'Gaming Society', rating: 4.9),
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
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for future image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              society.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

class Society {
  final String name;
  final double rating;
  // Future: Add imageUrl field here for easy image integration
  // final String? imageUrl;

  Society({
    required this.name,
    required this.rating,
    // this.imageUrl,
  });
}

class SearchResultsPage extends StatefulWidget {
  final String query;
  final List<String> items;

  const SearchResultsPage({super.key, required this.query, required this.items});

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
      _results = widget.items.where((i) => i.toLowerCase().contains(q)).toList();
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
