import 'package:flutter/material.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'custom_search_bar.dart';
import 'recent_tile.dart';
class SearchBottomSheet extends StatefulWidget {
  final List<Pharmacy> pharmacies;
  final Function(Pharmacy) onPharmacySelected;

  const SearchBottomSheet({
    super.key,
    required this.pharmacies,
    required this.onPharmacySelected,
  });

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  List<Pharmacy> _filteredPharmacies = [];
  bool _isSearching = false;
  String _selectedFilter = 'Toutes';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pharmacies != oldWidget.pharmacies && _isSearching) {
      _onSearchChanged();
    }
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('ô', 'o')
        .replaceAll('î', 'i');
  }

  void _onSearchChanged() {
    final query = _normalize(_searchController.text);
    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        _filteredPharmacies = widget.pharmacies.where((p) {
          final name = _normalize(p.nom);
          final address = _normalize(p.adresse ?? '');
          return name.contains(query) || address.contains(query);
        }).toList();
      } else {
        _filteredPharmacies = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.15, 0.5, 0.9],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                spreadRadius: 0,
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: colorScheme.surface,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 110,
                  flexibleSpace: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Indicateur de drag M3
                        Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomSearchBar(
                          controller: _searchController,
                          onClear: () => setState(() => _isSearching = false),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_isSearching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 8.0, // Reduced padding so chips are visible
                      bottom: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Toutes'),
                                selected: _selectedFilter == 'Toutes',
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (bool selected) {
                                  setState(() => _selectedFilter = 'Toutes');
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('De garde'),
                                selected: _selectedFilter == 'De garde',
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (bool selected) {
                                  setState(() => _selectedFilter = 'De garde');
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Ouvertes'),
                                selected: _selectedFilter == 'Ouvertes',
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (bool selected) {
                                  setState(() => _selectedFilter = 'Ouvertes');
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Proches'),
                                selected: _selectedFilter == 'Proches',
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (bool selected) {
                                  setState(() => _selectedFilter = 'Proches');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "Récents",
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // On pourra mettre les vrais récents ici plus tard
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final p = _filteredPharmacies[index];
                        return RecentTile(
                          title: p.nom,
                          subtitle: p.adresse ?? 'Adresse inconnue',
                          status: p.statutActuel,
                          onTap: () {
                            _sheetController.animateTo(
                              0.15,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                            widget.onPharmacySelected(p);
                          },
                        );
                      },
                      childCount: _filteredPharmacies.length,
                    ),
                  ),
                ),
              
              if (_isSearching && _filteredPharmacies.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          "Aucune pharmacie trouvée",
                          style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                        ),
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
  }
}
