import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile.dart';
import 'socieites.dart';
import 'about_us.dart'; // Add this import
import 'services/society_service.dart';
import 'services/api_config.dart';

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
  static const String _sessionUserStorageKey = 'unify.current_user';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _notificationsDrawerEpoch = 0;

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

  // All available societies (used to resolve joined society names to objects)
  // Will be populated from backend at startup.
  List<Society> _allSocieties = [];

  Map<String, dynamic>? _currentUser;
  final SocietyService _societyService = SocietyService();

  Timer? _notificationPollTimer;
  int? _lastSeenNotificationId;
  int? _activeBannerNotificationId;
  bool _pollingInFlight = false;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(_placeholderItems);
    _searchController.addListener(_onSearchChanged);
    _restoreSession();
    // Load societies from backend and then refresh ratings
    unawaited(_loadAllSocieties());
    unawaited(_refreshSocietyRatings());
  }

  void _startNotificationPollingIfNeeded() {
    if (_currentUser == null) {
      _stopNotificationPolling();
      return;
    }

    // Avoid creating multiple timers.
    if (_notificationPollTimer != null) return;

    // Poll immediately so unread notifications surface quickly.
    unawaited(_pollForNewNotifications());

    _notificationPollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_pollForNewNotifications());
    });
  }

  void _stopNotificationPolling({bool hideBanner = true}) {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = null;
    _lastSeenNotificationId = null;
    _activeBannerNotificationId = null;
    _unreadNotificationCount = 0;
    if (hideBanner && mounted) {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    }
  }

  Future<List<String>> _ensureJoinedSocietiesForPolling(String email) async {
    final existing = _joinedSocietyNames();
    if (existing.isNotEmpty) return existing;

    final res = await _societyService.getMySocieties(email: email);
    if (res['success'] == true) {
      final List<String> names =
          (res['societies'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      if (!mounted) return names;
      setState(() {
        _currentUser = {...?_currentUser, 'joinedSocieties': names};
      });
      unawaited(_persistCurrentUser(_currentUser));
      return names;
    }

    return <String>[];
  }

  Future<void> _pollForNewNotifications() async {
    if (!mounted) return;
    if (_pollingInFlight) return;

    final user = _currentUser;
    if (user == null) return;

    final email = (user['email'] as String?)?.toLowerCase().trim();
    if (email == null || email.isEmpty) return;

    _pollingInFlight = true;
    try {
      final societyNames = await _ensureJoinedSocietiesForPolling(email);
      if (societyNames.isEmpty) {
        if (mounted && _unreadNotificationCount != 0) {
          setState(() {
            _unreadNotificationCount = 0;
          });
        }
        return;
      }

      final token = user['auth_token'] as String?;
      final futures = societyNames.toSet().map((societyName) async {
        final res = await _societyService.getNotifications(
          societyName: societyName,
          viewerEmail: email,
          authToken: token,
        );
        if (res['success'] != true) return null;
        final raw = (res['notifications'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (raw.isEmpty) return null;

        final unreadCount = raw.where((m) => m['read'] != true).length;

        // Alert on the most recent unread notification.
        final unread = raw.firstWhere(
          (m) => m['read'] != true,
          orElse: () => <String, dynamic>{},
        );
        final latestUnread = unread.isEmpty
            ? null
            : _GlobalNotificationItem.fromJson(unread, societyName);

        return _NotificationPollResult(
          unreadCount: unreadCount,
          latestUnread: latestUnread,
        );
      }).toList();

      final results = await Future.wait(futures);
      final typed = results.whereType<_NotificationPollResult>().toList();

      final totalUnread = typed.fold<int>(0, (sum, r) => sum + r.unreadCount);
      if (mounted && totalUnread != _unreadNotificationCount) {
        setState(() {
          _unreadNotificationCount = totalUnread;
        });
      }

      final candidates = typed
          .map((r) => r.latestUnread)
          .whereType<_GlobalNotificationItem>()
          .toList();
      if (candidates.isEmpty) return;

      candidates.sort((a, b) {
        final cmp = b.createdAt.compareTo(a.createdAt);
        if (cmp != 0) return cmp;
        return b.id.compareTo(a.id);
      });
      final latest = candidates.first;

      final lastId = _lastSeenNotificationId;
      if (lastId != null && latest.id == lastId) return;

      _lastSeenNotificationId = latest.id;
      _showTopNotificationBanner(latest);
    } catch (_) {
      // Don't surface polling failures; the drawer already shows API errors.
      return;
    } finally {
      _pollingInFlight = false;
    }
  }

  void _showTopNotificationBanner(_GlobalNotificationItem item) {
    if (!mounted) return;

    _activeBannerNotificationId = item.id;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(
          '${item.societyName}: ${item.message}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              _activeBannerNotificationId = null;
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (_activeBannerNotificationId != item.id) return;
      messenger.hideCurrentMaterialBanner();
      _activeBannerNotificationId = null;
    });
  }

  String _badgeLabel(int count) {
    if (count > 99) return '99+';
    return '$count';
  }

  Future<void> _refreshSocietyRatings() async {
    try {
      final futures = _allSocieties.map((s) async {
        final res = await _societyService.getReviews(societyName: s.name);
        if (res['success'] == true) {
          final List<dynamic> raw = res['reviews'] as List<dynamic>? ?? [];
          if (raw.isNotEmpty) {
            final ratings = raw
                .map((m) => ((m as Map<String, dynamic>)['rating'] as num?)?.toDouble() ?? 0.0)
                .toList();
            final double avg = ratings.reduce((a, b) => a + b) / ratings.length;
            return Society(
              name: s.name,
              description: s.description,
              icon: s.icon,
              memberCount: s.memberCount,
              rating: avg,
              imageUrl: s.imageUrl,
            );
          }
        }
        return s;
      }).toList();

      final updated = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _allSocieties = updated;
      });
    } catch (_) {
      // ignore network errors; keep seeded values
    }
  }

  String _normalizeImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    // If the backend returns a relative path (e.g. /media/...), prefix base URL.
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'\/$'), '');
    if (s.startsWith('/')) return '$base$s';
    return '$base/$s';
  }

  Future<void> _loadAllSocieties({String? viewerEmail}) async {
    try {
      final res = await _societyService.listSocieties(viewerEmail: viewerEmail);
      if (res['success'] == true) {
        final List<dynamic> raw = res['societies'] as List<dynamic>? ?? [];
        final List<Society> mapped = raw.map((m) {
          final Map<String, dynamic> obj = m as Map<String, dynamic>;
          final String name = (obj['name'] ?? obj['title'] ?? '').toString();
          final String description = (obj['description'] ?? '').toString();
          final int memberCount = (obj['member_count'] ?? obj['members'] ?? obj['memberCount'] ?? 0) as int? ?? 0;
          final double rating = ((obj['rating'] ?? obj['average_rating'] ?? obj['avg_rating']) as num?)?.toDouble() ?? 0.0;
          final String rawImage = (obj['image_url'] ?? obj['image'] ?? obj['imageUrl'] ?? obj['picture'] ?? '').toString();
          final String imageUrl = _normalizeImageUrl(rawImage);
          return Society(
            name: name,
            description: description,
            icon: Icons.group,
            memberCount: memberCount,
            rating: rating,
            imageUrl: imageUrl,
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _allSocieties = mapped;
        });
        return;
      }
      // on failure, leave _allSocieties as-is (empty)
    } catch (_) {
      // ignore
    }
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_sessionUserStorageKey);
    if (rawUser == null || rawUser.isEmpty) {
      return;
    }

    try {
      final parsed = jsonDecode(rawUser) as Map<String, dynamic>;
      if (!mounted) return;

      setState(() {
        _currentUser = parsed;
      });

      _startNotificationPollingIfNeeded();

      final email = (parsed['email'] as String?)?.toLowerCase();
      if (email != null && email.isNotEmpty) {
        unawaited(_loadJoinedSocieties(email));
      }
    } catch (_) {
      await prefs.remove(_sessionUserStorageKey);
    }
  }

  Future<void> _persistCurrentUser(Map<String, dynamic>? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_sessionUserStorageKey);
      return;
    }
    await prefs.setString(_sessionUserStorageKey, jsonEncode(user));
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
    _stopNotificationPolling(hideBanner: false);
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
      unawaited(_persistCurrentUser(null));
      _stopNotificationPolling();
    } else if (value is Map<String, dynamic>) {
      setState(() {
        _currentUser = value;
      });
      unawaited(_persistCurrentUser(_currentUser));
      _startNotificationPollingIfNeeded();
      // Load joined societies from the API if the user object has an email
      final email = (value['email'] as String?)?.toLowerCase();
      if (email != null && email.isNotEmpty) {
        _loadJoinedSocieties(email);
      }
    }
  }

  Future<void> _loadJoinedSocieties(String email) async {
    final res = await _societyService.getMySocieties(email: email);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        final List<String> names =
            (res['societies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        _currentUser = {...?_currentUser, 'joinedSocieties': names};
      });
      unawaited(_persistCurrentUser(_currentUser));
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

  List<String> _joinedSocietyNames() {
    return (_currentUser?['joinedSocieties'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        <String>[];
  }

  void _openNotificationsHub() {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to view notifications.')),
      );
      return;
    }

    unawaited(_pollForNewNotifications());

    setState(() {
      _notificationsDrawerEpoch++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _openSocietiesPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocietiesPage(
          userEmail: _currentUser != null
              ? _currentUser!['email'] as String?
              : null,
          userAuthToken: _currentUser != null
              ? _currentUser!['auth_token'] as String?
              : null,
          // Provide the homepage's joined societies so the societies page
          // filters exactly match what the homepage shows.
          initialJoinedSocieties: _joinedSocietyNames(),
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

  void _openSocietyDetails(Society society) {
    _navigateToSocietyDetails(society);
  }

  void _navigateToSocietyDetails(
    Society society, {
    bool initialJoined = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocietyDetailsPage(
          name: society.name,
          description: society.description,
          imageUrl: society.imageUrl,
          icon: society.icon,
          userEmail: _currentUser != null
              ? (_currentUser!['email'] as String?)
              : null,
          userAuthToken: _currentUser != null
              ? (_currentUser!['auth_token'] as String?)
              : null,
          initialJoined: initialJoined,
          initialMemberCount: society.memberCount,
          initialAverageRating: society.rating,
          onMembershipChanged: (joined, count) {
            setState(() {
              // update the local _allSocieties list so UI stays in sync
              _allSocieties = _allSocieties.map((s) {
                if (s.name == society.name) {
                  return Society(
                    name: s.name,
                    description: s.description,
                    icon: s.icon,
                    memberCount: count,
                    rating: s.rating,
                    imageUrl: s.imageUrl,
                  );
                }
                return s;
              }).toList();
              // also update _currentUser.joinedSocieties when membership changes
              final js =
                  (_currentUser?['joinedSocieties'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              final names = js.map((e) => e.toLowerCase().trim()).toList();
              if (joined) {
                if (!names.contains(society.name.toLowerCase().trim())) {
                  final newList = [...js, society.name];
                  _currentUser = {...?_currentUser, 'joinedSocieties': newList};
                }
              } else {
                final newList = js
                    .where(
                      (n) =>
                          n.toLowerCase().trim() !=
                          society.name.toLowerCase().trim(),
                    )
                    .toList();
                _currentUser = {...?_currentUser, 'joinedSocieties': newList};
              }
            });
            unawaited(_persistCurrentUser(_currentUser));
          },
          onAverageRatingChanged: (rating) {
            setState(() {
              _allSocieties = _allSocieties.map((s) {
                if (s.name == society.name) {
                  return Society(
                    name: s.name,
                    description: s.description,
                    icon: s.icon,
                    memberCount: s.memberCount,
                    rating: rating,
                    imageUrl: s.imageUrl,
                  );
                }
                return s;
              }).toList();
            });
          },
        ),
      ),
    );
  }

  String _currentUserDisplayName() {
    final user = _currentUser;
    if (user == null) return '';

    final raw =
        (user['name'] ?? user['display_name'] ?? user['username'] ?? user['email'])
            ?.toString()
            .trim();
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('@')) return raw.split('@').first;
    return raw;
  }

  String _welcomeText() {
    if (_currentUser == null) return 'Welcome';
    final name = _currentUserDisplayName();
    if (name.isEmpty) return 'Welcome back';
    return 'Welcome back, $name';
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joinedSocietyNames();
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _currentUser != null
          ? Drawer(
              child: AllNotificationsPanel(
                key: ValueKey(_notificationsDrawerEpoch),
                currentUser: _currentUser,
                joinedSocietyNames: joined,
                onNotificationReadChanged: () {
                  unawaited(_pollForNewNotifications());
                },
              ),
            )
          : null,
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
            tooltip: 'Notifications',
            onPressed: _openNotificationsHub,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        _badgeLabel(_unreadNotificationCount),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
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
                _welcomeText(),
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
              // Joined societies quick access
              if (_currentUser != null) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final joinedNames =
                        (_currentUser!['joinedSocieties'] as List?)
                            ?.map((e) => e.toString().toLowerCase().trim())
                            .toSet() ??
                        <String>{};
                    final joined = _allSocieties
                        .where(
                          (s) =>
                              joinedNames.contains(s.name.toLowerCase().trim()),
                        )
                        .toList();

                    if (joined.isEmpty) {
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'You haven\'t joined any societies yet',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap "Find societies" to browse and join groups.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _openSocietiesPage,
                                child: const Text('Find societies'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your societies',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: joined.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final s = joined[index];
                              return InkWell(
                                onTap: () => _navigateToSocietyDetails(
                                  s,
                                  initialJoined: true,
                                ),
                                child: SizedBox(
                                  width: 220,
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            child: Icon(s.icon, size: 28),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  s.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${s.memberCount} members · ${s.rating} ★',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
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
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ],
              // Prompt when not signed in
              if (_currentUser == null) ...[
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.login),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Sign in to see your societies',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Create an account or sign in to quickly access societies you\'ve joined.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _openAuthPage,
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Center(
                child: ElevatedButton.icon(
                  onPressed: _openSocietiesPage,
                  icon: const Icon(Icons.groups, size: 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 42),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
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
              SizedBox(
                height: 350,
                child: HeroCarousel(
                  societies: _allSocieties,
                  userEmail: _currentUser != null
                      ? (_currentUser!['email'] as String?)
                      : null,
                  userAuthToken: _currentUser != null
                      ? (_currentUser!['auth_token'] as String?)
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              ReviewsSection(
                societies: _allSocieties,
                userEmail: _currentUser != null
                    ? (_currentUser!['email'] as String?)
                    : null,
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 18),
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

class AllNotificationsPanel extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final List<String> joinedSocietyNames;
  final VoidCallback? onNotificationReadChanged;

  const AllNotificationsPanel({
    super.key,
    required this.currentUser,
    required this.joinedSocietyNames,
    this.onNotificationReadChanged,
  });

  @override
  State<AllNotificationsPanel> createState() => _AllNotificationsPanelState();
}

class _AllNotificationsPanelState extends State<AllNotificationsPanel> {
  final SocietyService _societyService = SocietyService();

  bool _loading = true;
  List<_GlobalNotificationItem> _items = [];
  List<String> _societyNames = [];
  String? _emptyMessage;

  String? get _viewerEmail => widget.currentUser?['email'] as String?;
  String? get _authToken => widget.currentUser?['auth_token'] as String?;

  @override
  void initState() {
    super.initState();
    _societyNames = List<String>.from(widget.joinedSocietyNames);
    _load();
  }

  @override
  void didUpdateWidget(covariant AllNotificationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldList = List<String>.from(oldWidget.joinedSocietyNames)..sort();
    final newList = List<String>.from(widget.joinedSocietyNames)..sort();
    if (!listEquals(oldList, newList)) {
      _societyNames = List<String>.from(widget.joinedSocietyNames);
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final email = _viewerEmail;
    if (email == null || email.isEmpty) {
      setState(() {
        _items = [];
        _emptyMessage = 'Please sign in to view notifications.';
        _loading = false;
      });
      return;
    }

    if (_societyNames.isEmpty) {
      final joinedRes = await _societyService.getMySocieties(email: email);
      if (joinedRes['success'] == true) {
        _societyNames = (joinedRes['societies'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList();
      } else {
        if (!mounted) return;
        setState(() {
          _items = [];
          _emptyMessage =
              joinedRes['message']?.toString() ?? 'Could not load societies.';
          _loading = false;
        });
        return;
      }
    }

    if (_societyNames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _emptyMessage = 'Join a society to receive notifications.';
        _loading = false;
      });
      return;
    }

    final failures = <String>[];
    final futures = _societyNames.toSet().map((societyName) async {
      final res = await _societyService.getNotifications(
        societyName: societyName,
        viewerEmail: email,
        authToken: _authToken,
      );
      if (res['success'] != true) {
        failures.add(
          '$societyName: ${res['message']?.toString() ?? 'Could not load.'}',
        );
        return <_GlobalNotificationItem>[];
      }
      final raw = (res['notifications'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      return raw
          .map((m) => _GlobalNotificationItem.fromJson(m, societyName))
          .toList();
    }).toList();

    final lists = await Future.wait(futures);
    final merged = lists.expand((e) => e).toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _items = merged;
      if (merged.isEmpty && failures.isNotEmpty) {
        _emptyMessage = failures.first;
      } else {
        _emptyMessage = null;
      }
      _loading = false;
    });
  }

  String _timestampLabel(DateTime utc) {
    final local = utc.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yy = (local.year % 100).toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy  $hh:$min';
  }

  Future<void> _markRead(_GlobalNotificationItem item) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to mark read.')),
      );
      return;
    }

    final res = await _societyService.markNotificationRead(
      notificationId: item.id,
      authToken: token,
    );

    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _items = _items
            .map(
              (x) => x.id == item.id ? x.copyWith(read: true) : x,
            )
            .toList();
      });

      widget.onNotificationReadChanged?.call();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message']?.toString() ?? 'Updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _emptyMessage ?? 'No notifications yet.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final n = _items[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              n.message,
                              style: TextStyle(
                                fontWeight: n.read
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${n.societyName} · ${_timestampLabel(n.createdAt)}',
                            ),
                            trailing: n.read
                                ? null
                                : TextButton(
                                    onPressed: () => _markRead(n),
                                    child: const Text('Mark read'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalNotificationItem {
  final int id;
  final String type;
  final String message;
  final String link;
  final DateTime createdAt;
  final bool read;
  final String societyName;

  const _GlobalNotificationItem({
    required this.id,
    required this.type,
    required this.message,
    required this.link,
    required this.createdAt,
    required this.read,
    required this.societyName,
  });

  factory _GlobalNotificationItem.fromJson(
    Map<String, dynamic> json,
    String societyName,
  ) {
    return _GlobalNotificationItem(
      id: (json['id'] as int?) ?? 0,
      type: (json['type'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      link: (json['link'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      read: json['read'] == true,
      societyName: societyName,
    );
  }

  _GlobalNotificationItem copyWith({bool? read}) {
    return _GlobalNotificationItem(
      id: id,
      type: type,
      message: message,
      link: link,
      createdAt: createdAt,
      read: read ?? this.read,
      societyName: societyName,
    );
  }
}

class _NotificationPollResult {
  final int unreadCount;
  final _GlobalNotificationItem? latestUnread;

  const _NotificationPollResult({
    required this.unreadCount,
    required this.latestUnread,
  });
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
  final List<Society> societies;
  final String? userEmail;
  final String? userAuthToken;

  const HeroCarousel({
    super.key,
    required this.societies,
    this.userEmail,
    this.userAuthToken,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  bool _hovering = false;
  List<Society> get _societies => widget.societies;

  void _openSocietyDetails(Society society) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocietyDetailsPage(
          name: society.name,
          description: society.description,
          imageUrl: society.imageUrl,
          icon: society.icon,
          initialMemberCount: society.memberCount,
          initialAverageRating: society.rating,
          userEmail: widget.userEmail,
          userAuthToken: widget.userAuthToken,
        ),
      ),
    );
  }

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
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool showArrows = !_hovering ? false : !isMobile;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _societies.length,
              itemBuilder: (context, index) {
                final society = _societies[index];
                return SocietyCard(
                  society: society,
                  onTap: () => _openSocietyDetails(society),
                );
              },
            ),
          ),

          // Left arrow (centered to carousel)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: AnimatedOpacity(
                opacity: showArrows ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.black.withOpacity(0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () {
                      final target = (_currentPage - 1).clamp(
                        0,
                        _societies.length - 1,
                      );
                      _pageController.animateToPage(
                        target,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Right arrow (centered to carousel)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: AnimatedOpacity(
                opacity: showArrows ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.black.withOpacity(0.35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: () {
                      final target = (_currentPage + 1).clamp(
                        0,
                        _societies.length - 1,
                      );
                      _pageController.animateToPage(
                        target,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Page indicators at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
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
      ),
    );
  }
}

class SocietyCard extends StatelessWidget {
  final Society society;
  final VoidCallback? onTap;

  const SocietyCard({super.key, required this.society, this.onTap});

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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Show network image when available, otherwise a styled placeholder
                society.imageUrl.trim().isEmpty
                    ? Container(
                        color: Theme.of(context).colorScheme.primary,
                        child: Center(
                          child: Icon(
                            society.icon,
                            size: 64,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      )
                    : Image.network(
                        society.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context).colorScheme.primary,
                          child: Center(
                            child: Icon(
                              society.icon,
                              size: 64,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
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
                            society.rating.toStringAsFixed(1),
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
        ),
      ),
    );
  }
}

class ReviewsSection extends StatefulWidget {
  final List<Society> societies;
  final String? userEmail;

  const ReviewsSection({super.key, required this.societies, this.userEmail});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  final SocietyService _service = SocietyService();
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void didUpdateWidget(covariant ReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If societies were previously empty and are now populated, reload reviews.
    if ((oldWidget.societies.isEmpty) && widget.societies.isNotEmpty) {
      unawaited(_loadSampleReviews());
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSampleReviews();
  }

  Future<void> _loadSampleReviews() async {
    setState(() => _loading = true);
    final List<Map<String, dynamic>> collected = [];
    // Build a list of societies to query: prefer provided ones, else fetch from API
    final List<Society> societiesToQuery = [];
    if (widget.societies.isNotEmpty) {
      societiesToQuery.addAll(widget.societies);
    } else {
      try {
        final res = await _service.listSocieties();
        if (res['success'] == true) {
          final List<dynamic> raw = res['societies'] as List<dynamic>? ?? [];
          for (final obj in raw) {
            final m = obj as Map<String, dynamic>;
            societiesToQuery.add(Society(
              name: (m['name'] ?? '').toString(),
              description: (m['description'] ?? '').toString(),
              icon: Icons.group,
              memberCount: (m['member_count'] ?? 0) as int? ?? 0,
              rating: ((m['average_rating'] ?? m['rating']) as num?)?.toDouble() ?? 0.0,
              imageUrl: (m['image_url'] ?? '').toString(),
            ));
          }
        }
      } catch (_) {
        // ignore
      }
    }

    if (societiesToQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        _reviews = [];
        _loading = false;
      });
      return;
    }

    final seenIds = <int>{};
    // Iterate societies in order and collect up to 5 unique reviews from DB
    for (final s in societiesToQuery) {
      try {
        final res = await _service.getReviews(societyName: s.name, viewerEmail: widget.userEmail);
        if (res['success'] == true) {
          final List<Map<String, dynamic>> revs = (res['reviews'] as List<dynamic>).cast<Map<String, dynamic>>();
          for (final r in revs) {
            final id = (r['id'] as num?)?.toInt();
            if (id == null) continue;
            if (seenIds.contains(id)) continue;
            seenIds.add(id);
            collected.add({
              ...r,
              'society_name': s.name,
              'society_rating': s.rating,
            });
            if (collected.length >= 5) break;
          }
        }
      } catch (_) {
        // ignore individual society failures
      }
      if (collected.length >= 5) break;
    }

    // no further fallback; we've already attempted to collect from available societies

    if (!mounted) return;
    setState(() {
      _reviews = collected;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Community reviews',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
            ? Text(
                'No reviews available yet.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            : SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final r = _reviews[index];
                    return SizedBox(
                      width: 320,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    r['society_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text((r['rating'] ?? 0).toString()),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  (r['comment'] ?? '').toString(),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'By ${r['author_display_name'] ?? r['author'] ?? 'User'}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // navigate to society details
                                      final society = widget.societies
                                          .firstWhere(
                                            (s) =>
                                                s.name ==
                                                (r['society_name'] ?? ''),
                                            orElse: () =>
                                                widget.societies.first,
                                          );
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SocietyDetailsPage(
                                            name: society.name,
                                            description: society.description,
                                            imageUrl: society.imageUrl,
                                            icon: society.icon,
                                            initialMemberCount:
                                                society.memberCount,
                                            initialAverageRating:
                                                society.rating,
                                            userEmail: widget.userEmail,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('View'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}

class Society {
  final String name;
  final String description;
  final IconData icon;
  final int memberCount;
  final double rating;
  final String imageUrl;

  Society({
    required this.name,
    required this.description,
    required this.icon,
    required this.memberCount,
    required this.rating,
    required this.imageUrl,
  });
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
