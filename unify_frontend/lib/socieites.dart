import 'package:flutter/material.dart';

class SocietiesPage extends StatefulWidget {
  const SocietiesPage({super.key});

  @override
  State<SocietiesPage> createState() => _SocietiesPageState();
}

class _SocietiesPageState extends State<SocietiesPage> {
  final TextEditingController _searchController = TextEditingController();
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
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(_allSocieties);
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_allSocieties);
      } else {
        _filtered = _allSocieties.where((s) => s.toLowerCase().contains(q)).toList();
      }
    });
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

                // Dropdown results (suggestions) while typing
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
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final name = _filtered[index];
                                return ListTile(
                                  leading: const Icon(Icons.groups),
                                  title: Text(name),
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
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(name[0])),
                    title: Text(name),
                    subtitle: const Text('Placeholder description to fill space'),
                    onTap: () {},
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
