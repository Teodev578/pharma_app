import 'package:flutter/material.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'custom_search_bar.dart';
import 'action_button.dart';
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

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        _filteredPharmacies = widget.pharmacies.where((p) {
          final name = p.nom.toLowerCase();
          final address = p.adresse?.toLowerCase() ?? '';
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
            color: colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Indicateur de drag M3
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
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

              if (!_isSearching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Lieux",
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ActionButton(
                              icon: Icons.local_pharmacy,
                              label: "Proches",
                              color: Colors.green,
                            ),
                            ActionButton(
                              icon: Icons.star,
                              label: "Favoris",
                              color: Colors.orange,
                            ),
                            ActionButton(
                              icon: Icons.add,
                              label: "Ajouter",
                              color: Colors.blue,
                            ),
                          ],
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
        );
      },
    );
  }
}
