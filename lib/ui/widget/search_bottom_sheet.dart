import 'package:flutter/material.dart';
import 'custom_search_bar.dart';
import 'action_button.dart';
import 'recent_tile.dart';

class SearchBottomSheet extends StatelessWidget {
  const SearchBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
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
                    const CustomSearchBar(),
                  ],
                ),
              ),

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
                      const RecentTile(
                        title: "Pharmacie Conseil",
                        subtitle: "Bolou Kpeta • Ouvert jusqu'à 22h",
                      ),
                      const RecentTile(
                        title: "Pharmacie de la Nation",
                        subtitle: "Avenue PYA • Garde aujourd'hui",
                      ),
                      const RecentTile(
                        title: "Pharmacie du Grand Marché",
                        subtitle: "Assigamé • Ouvert 24/7",
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
