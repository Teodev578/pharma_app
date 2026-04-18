import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:latlong2/latlong.dart';
import 'custom_search_bar.dart';
import 'recent_tile.dart';

class SearchBottomSheet extends StatefulWidget {
  final List<Pharmacy> pharmacies;
  final Function(Pharmacy) onPharmacySelected;
  // Position de l'utilisateur pour le tri par proximité
  final LatLng? userPosition;

  const SearchBottomSheet({
    super.key,
    required this.pharmacies,
    required this.onPharmacySelected,
    this.userPosition,
  });

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  List<Pharmacy> _filteredPharmacies = [];
  bool _isSearching = false;
  String _selectedFilter = 'Toutes';

  @override
  void initState() {
    super.initState();
    _filteredPharmacies = widget.pharmacies;
    _searchController.addListener(_applyFilters);
    _sheetController.addListener(_onSheetScroll);
  }

  void _onSheetScroll() {
    if (_sheetController.size < 0.85 && FocusManager.instance.primaryFocus?.hasFocus == true) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.removeListener(_onSheetScroll);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pharmacies != oldWidget.pharmacies) {
      _applyFilters();
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

  /// Distance haversine en mètres entre deux points
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // rayon Terre en mètres
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Formate une distance en m
  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _applyFilters() {
    final query = _normalize(_searchController.text);
    final userPos = widget.userPosition;

    List<Pharmacy> results = widget.pharmacies.where((p) {
      final name = _normalize(p.nom);
      final address = _normalize(p.adresse ?? '');
      bool matchesSearch =
          query.isEmpty || name.contains(query) || address.contains(query);
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Ouvertes') {
        final s = p.statutActuel?.toLowerCase();
        return s == 'ouverte' || s == 'ouvert' || s == 'de garde';
      }
      return true;
    }).toList();

    // Tri par proximité si filtre "Proches" ou si position disponible
    if (_selectedFilter == 'Proches' && userPos != null) {
      results.sort((a, b) {
        final da = (a.latitude != null && a.longitude != null)
            ? _haversineDistance(userPos.latitude, userPos.longitude, a.latitude!, a.longitude!)
            : double.infinity;
        final db = (b.latitude != null && b.longitude != null)
            ? _haversineDistance(userPos.latitude, userPos.longitude, b.latitude!, b.longitude!)
            : double.infinity;
        return da.compareTo(db);
      });
    }

    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredPharmacies = results;
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                          onTap: () {
                            if (_sheetController.size < 0.9) {
                              _sheetController.animateTo(
                                0.9,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(64.0),
                    child: Container(
                      color: colorScheme.surface,
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 8.0,
                        bottom: 16.0,
                      ),
                      child: SingleChildScrollView(
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
                                _applyFilters();
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
                                _applyFilters();
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
                                _applyFilters();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_filteredPharmacies.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                      child: Text(
                        '${_filteredPharmacies.length} résultat${_filteredPharmacies.length > 1 ? 's' : ''}',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final p = _filteredPharmacies[index];
                      final userPos = widget.userPosition;
                      final String subtitle;
                      if (_selectedFilter == 'Proches' &&
                          userPos != null &&
                          p.latitude != null &&
                          p.longitude != null) {
                        final dist = _haversineDistance(
                          userPos.latitude, userPos.longitude,
                          p.latitude!, p.longitude!,
                        );
                        subtitle = '${_formatDistance(dist)} · ${p.adresse ?? 'Adresse inconnue'}';
                      } else {
                        subtitle = p.adresse ?? 'Adresse inconnue';
                      }
                      return RecentTile(
                        title: p.nom,
                        subtitle: subtitle,
                        status: p.statutActuel,
                        searchQuery: _isSearching ? _searchController.text : null,
                        onTap: () {
                          _sheetController.animateTo(
                            0.15,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                          widget.onPharmacySelected(p);
                        },
                      );
                    }, childCount: _filteredPharmacies.length),
                  ),
                ),

                if (_isSearching && _filteredPharmacies.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Aucune pharmacie trouvée",
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _selectedFilter = 'Toutes';
                                _isSearching = false;
                              });
                              _applyFilters();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réinitialiser la recherche'),
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
