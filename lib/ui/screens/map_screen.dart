import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Pour la fonction compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

// Importations de tes fichiers locaux
import 'package:pharma_app/ui/widget/floating_map_buttons.dart';
import 'package:pharma_app/ui/widget/search_bottom_sheet.dart';
import 'package:pharma_app/models/pharmacy.dart';
import 'package:pharma_app/services/supabase_service.dart';

/// FONCTION GLOBALE POUR ISOLATE (THREAD SÉPARÉ)
/// Flutter tourne par défaut sur 1 seul thread (le Main/UI thread).
/// S'il doit décoder un gros fichier JSON lourd (le style de la carte MapTiler), l'écran va se figer ("jank").
/// VTR (Vector Tile Renderer) demande un certain temps pour décoder son thème (plusieurs dizaines de ms).
/// En passant par la fonction `compute`, ce travail complexe sera réalisé sur un "Isolate" (Un nouveau coeur/thread).
/// ATTENTION : Cette méthode doit être absolument globale (en dehors d'une classe) afin que Flutter puisse la paraléliser de façon autonome.
Future<vtr.Theme> _parseVectorTheme(Map<String, dynamic> params) async {
  final String jsonStr = params['jsonStr'];
  final String bgHex = params['bgHex'];
  final Map<String, dynamic> jsonStyle = jsonDecode(jsonStr);

  if (jsonStyle.containsKey('layers')) {
    for (var layer in jsonStyle['layers']) {
      if (layer['type'] == 'background') {
        layer['paint'] ??= {};
        layer['paint']['background-color'] = bgHex;
      }
    }
  }
  return vtr.ThemeReader().read(jsonStyle);
}

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- CONSTANTES ET CONFIGURATIONS ---
  // Le centre de la carte lors de l'ouverture de l'application (latitude et longitude).
  final LatLng _initialCenter = const LatLng(6.137, 1.212);
  
  // Ce contrôleur nous permet de "conduire" la carte de façon programmatique (ex: forcer un déplacement de caméra).
  final MapController _mapController = MapController();
  
  // Clé d'API (obligatoire pour récupérer les tuiles PBF de chez MapTiler)
  final String mapTilerKey = 'pg76rH7Ad8bNzkP7pnwf';

  // --- VARIABLES D'ÉTAT (UI ET CACHE) ---
  // Theme contient les couleurs, routes, et libellés décodés. Sans thème complet, la carte ne rend pas les chemins.
  vtr.Theme? _mapTheme;
  
  // Stocke l'ancienne luminosité pour vérifier à chaque draw si on a changé de thème Android/iOS (Clair => Sombre).
  Brightness? _lastBrightness;
  
  // Variables boolean de Chargement (Indispensable pour le loader UI discret et la parade anti-freeze initial).
  bool _isLoadingPharmacies = true;
  bool _isThemeLoading = false;

  // Variables stockant nos données de base (Modèle Supabase), et nos widgets affichables de carte (Markers).
  List<Pharmacy> _pharmacies = [];
  List<Marker> _cachedMarkers = []; // Les marqueurs pré-calculés, pour éviter la reconstruction native pendant chaque scroll !

  // Ce StreamController sert de "pont" : il émet un événement vers le CurrentLocationLayer pour l'aligner sans devoir passer par des setState().
  late final StreamController<double?> _alignController;
  
  // L'architecte des tuiles : gère le réseau, la queue de download et le cache mémoire des fragments de carte (.pbf).
  late final TileProviders _tileProviders;

  @override
  void initState() {
    super.initState();
    _alignController = StreamController<double?>.broadcast();

    // EXTRÊMEMENT IMPORTANT : Initialisation *unique* du Cache Mémoire Vectoriel.
    // Cette configuration alloue généreusement un maximum de 50 MB de RAM pour conserver la ville scannée au chaud.
    // Les tuiles PBF (Protocolbuffer Binary Format) sont des fichiers compressés qui retiennent une incroyable densité d'immeubles et de rues.
    // Plus le maxSizeBytes est grand, moins le composant Delegate refera de ping réseaux sur maptiler.com (Gain datas pour l'utilisateur !).
    _tileProviders = TileProviders({
      'maptiler_planet': MemoryCacheVectorTileProvider(
        maxSizeBytes: 50 * 1024 * 1024,
        delegate: NetworkVectorTileProvider(
          urlTemplate:
              'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$mapTilerKey',
          maximumZoom: 14, // On s'arrête de requêter du nouveau polygone après x14 (ensuite on fait de l'agrandissement d'image pur pour éviter de douiller l'API).
        ),
      ),
    });

    _fetchPharmacies();
  }

  /// FETCH PHARMACIES :
  /// Se connecte à Supabase, télécharge la liste de données brutes, et enregistre en mémoire.
  Future<void> _fetchPharmacies() async {
    try {
      final pharmacies = await SupabaseService().getPharmacies();
      
      // Mettre toujours 'mounted' avant 'setState' (Vérifie si la Map n'a pas été fermée entre-temps par une nav).
      if (mounted) {
        setState(() {
          _pharmacies = pharmacies;
          // TRICK DE PERFORMANCE (STAGGERED LOADING) : 
          // On obtient nos propriétés, mais OUI on fait expressément de NE PAS parser les marqueurs tout de suite !
          // Le VectorTileLayer au même moment est en train de réclamer tout le CPU pour décoder et projeter les PBF de MapTiler. 
          // Si on déclenchait _updateMarkers() massivement ici, on taperait le thread principal -> lag épouvantable.
        });

        // On gèle intentionnellement la naissance des clusters de 600ms pour laisser la Map charger dans le vide.
        await Future.delayed(const Duration(milliseconds: 600));
        
        if (mounted) {
          _updateMarkers(); // Lancement différé !
        }
      }
    } catch (e) {
      debugPrint("Erreur Supabase: $e");
      // Faceback d'erreur : enlever les loaders pour libérer la Map
      if (mounted) setState(() => _isLoadingPharmacies = false);
    }
  }

  /// CRÉATION DES MARQUEURS :
  /// Transforme de pures Data (latitude/longitude) en véritables widgets "Marker" FlutterMap prêts à clouer.
  void _updateMarkers() {
    final newMarkers = _pharmacies
        // Ligne vitale : ignorer catégoriquement toute pharmacie qui n'aurait pas été géolocalisée
        .where((p) => p.latitude != null && p.longitude != null)
        // La fonction .map itérative bâtit chaque Marker physique un par un.
        .map(
          (p) => _buildPharmacyMarker(
            context,
            LatLng(p.latitude!, p.longitude!),
            p,
          ),
        )
        .toList(); // Finalise l'Itérable en Liste d'objet natif

    if (mounted) {
      setState(() {
        // En poussant "newMarkers" vers _cachedMarkers, on "débloque" la porte affichant le Layer de Clusters 
        _cachedMarkers = newMarkers;
        // Permet au "Loader Overlay Central" du dessus de la carte de disparaitre de l'écran.
        _isLoadingPharmacies = false;
      });
    }
  }

  @override
  /// EVENT DE SYSTÈME (didChangeDependencies) : 
  /// S'exécute quand l'InheritedWidget système subit une modification profonde (comme le Dark mode trigger par le Control Center de l'OS).
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);

    // TECHNIQUE : N'exécuter que si on a RÉELLEMENT changé de mode lumineux.
    // Cela empêche un re-chargement complet involontaire de la carte si l'utilisateur quitte provisoirement l'app pour aller lire un SMS.
    if (_lastBrightness != theme.brightness) {
      _lastBrightness = theme.brightness;

      // Déduction de notre fameuse Hexadécimale d'arrière plan (sur lequel viendra peindre MapTiler ses parcs, mers, etc).
      final bgColor = theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : const Color(0xFFF2F4F5);

      // Envoie la couleur du système injecter le JSON
      _loadVectorMapTheme(theme.brightness, bgColor);

      // On s'assure de rafraichir aussi la couleur des bordures de nos *Marqueurs* UI.
      // Le theme.colorScheme de la bordure du marqueur s'invaliderait pas de lui-même car il est listé statique dans un cache.
      if (_pharmacies.isNotEmpty) {
        setState(() => _isLoadingPharmacies = true); // Affiche le spinner "optimisation…"
        
        // Un micro-délai (400ms) pour laisser les couleurs et fonts OS se rafraîchir en priorité
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _updateMarkers();
        });
      }
    }
  }

  /// Gestion du thème vectoriel avec Cache Disque et Thread séparé
  Future<void> _loadVectorMapTheme(Brightness brightness, Color bgColor) async {
    if (_isThemeLoading) return;
    setState(() => _isThemeLoading = true);

    final styleId = brightness == Brightness.dark
        ? 'streets-v2-dark'
        : 'streets-v2';
    final cacheKey = 'map_style_$styleId';

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$cacheKey.json');
      String rawJsonStr = '';

      if (await file.exists()) {
        rawJsonStr = await file.readAsString();
      } else {
        final response = await http.get(
          Uri.parse(
            'https://api.maptiler.com/maps/$styleId/style.json?key=$mapTilerKey',
          ),
        );
        if (response.statusCode == 200) {
          rawJsonStr = response.body;
          await file.writeAsString(rawJsonStr);
        }
      }

      if (rawJsonStr.isNotEmpty && mounted) {
        final bgHex =
            '#${bgColor.value.toRadixString(16).substring(2, 8).toUpperCase()}';

        // EXECUTION HORS DU THREAD PRINCIPAL
        final decodedTheme = await compute(_parseVectorTheme, {
          'jsonStr': rawJsonStr,
          'bgHex': bgHex,
        });

        if (mounted) {
          setState(() {
            _mapTheme = decodedTheme;
            _isThemeLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erreur chargement thème: $e");
      if (mounted) setState(() => _isThemeLoading = false);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _alignController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? theme.colorScheme.surface
        : const Color(0xFFF2F4F5);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                backgroundColor: bgColor,
                initialCenter: _initialCenter,
                initialZoom: 15.0,
                maxZoom: 20.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // ================= COUCHES DE LA CARTE (Z-Index / Ordre de projection vectorielle) =================
                
                // COUCHE N°1 : FOND DE CARTE (VECTORIELLE)
                // Rend les plans, bâtiments, océans en format dessin SVG-like redimensionnable à l'infini (Sans pixelisation).
                if (_mapTheme != null)
                  VectorTileLayer(
                    theme: _mapTheme!,
                    tileProviders: _tileProviders,
                  ),

                // COUCHE N°2 : POSITION UTILISATEUR LITTÉRALE (Point bleu et Cône de vue directionnel)
                CurrentLocationLayer(
                  alignPositionStream: _alignController.stream, // Écoute notre bouton flottant sans forcer de rebuild général
                  style: LocationMarkerStyle(
                    marker: DefaultLocationMarker(
                      color: theme.colorScheme.primary, // Cible le BLEU ou COULEUR PRINCIPALE de votre charte graphique
                    ),
                    markerSize: const Size(20, 20),
                  ),
                ),

                // COUCHE N°3 : MARQUEURS PHARMACIES "CLUSTERS" (Boules agglomérées intelligentes)
                // Conditions cumulatives : S'affichent uniquement SI pharmacies converties + Aucun delay/loading artificiel n'est de rigueur (Delay de 600ms au boot ok !).
                if (!_isLoadingPharmacies && _cachedMarkers.isNotEmpty)
                  Builder(
                    builder: (context) {
                      // HACK CRUCIAL :  En introduisant un "Builder", on confie un nouveau Context localisé pour MapCamera.of().
                      // C'est requis par "MarkerClusterLayer" qui doit fouiller les parents à la recherche du "FlutterMap" engine.
                      return MarkerClusterLayer(
                        mapController: _mapController,
                        mapCamera: MapCamera.of(context), 
                        options: MarkerClusterLayerOptions(
                          markers: _cachedMarkers, // Récupération brute du Cache qu'on a mis en place => 0 perte de frame
                          size: const Size(44, 44),
                          // maxClusterRadius dicte l'aimant magnétique : au bout de 45 pixels, les sphères se scindent pour révéler chaque pharmacie
                          maxClusterRadius: 45, 
                          builder: (context, markers) =>
                              _buildClusterWidget(markers.length), // Génère le badge chiffré "6" / "2"
                        ),
                      );
                    },
                  ),

                // 4. BOUTONS FLOTTANTS
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FloatingMapButtons(
                        mapController: _mapController,
                        onMyLocationPressed: () => _alignController.add(15.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 5. BARRE DE RECHERCHE
            SearchBottomSheet(
              pharmacies: _pharmacies,
              onPharmacySelected: (pharmacy) {
                if (pharmacy.latitude != null && pharmacy.longitude != null) {
                  _mapController.move(
                    LatLng(pharmacy.latitude!, pharmacy.longitude!),
                    16.0,
                  );
                  _showPharmacyDetails(context, pharmacy);
                }
              },
            ),

            // 6. LOADER
            if (_isLoadingPharmacies || _isThemeLoading) _buildTopLoader(theme),
          ],
        ),
      ),
    );
  }

  // Widget pour les groupes de marqueurs
  Widget _buildClusterWidget(int count) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget loader discret en haut
  Widget _buildTopLoader(ThemeData theme) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  "Optimisation de la carte...",
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// CONSTRUCTION D'UN MARQUEUR INDIVIDUEL COMPLET
  /// Fabrique un "bouton punaise géographique" complet combinant widget, logique et position.
  Marker _buildPharmacyMarker(
    BuildContext context,
    LatLng point,
    Pharmacy pharmacy,
  ) {
    final isOpen = pharmacy.statutActuel == 'Ouvert';
    final colorScheme = Theme.of(context).colorScheme;

    return Marker(
      point: point, // Coordonnées GPS immuables
      width: 44,
      height: 44,
      // OPTIMISATION ABSOLUE : `RepaintBoundary` (Limite logicielle de redessinage)
      // Lors d'un drag, Flutter tente de "rafraîchir" les couleurs/shadows de façon intemestive au fil des ms.
      // Cette balise instruit au moteur Skia/Impeller : "Ce container est désormais inerte ; mets le en cache image et dessine le plat." 
      // Cette unique ligne donne un boost de FPS démentiel quand on scrolle par dessus la ville avec tous ces noeuds graphiques :
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () => _showPharmacyDetails(context, pharmacy), // Modal interactif
          child: Container(
            decoration: BoxDecoration(
              color: isOpen ? Colors.green.shade100 : Colors.red.shade100, // Background teinte en Statut (V/R)
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.surface, width: 3),
            ),
            child: Icon(
              Icons.local_pharmacy,
              color: isOpen ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // Détails de la pharmacie (BottomSheet)
  void _showPharmacyDetails(BuildContext context, Pharmacy pharmacy) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pharmacy.nom,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (pharmacy.adresse != null)
                Text(pharmacy.adresse!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.directions),
                  label: const Text("Itinéraire"),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
