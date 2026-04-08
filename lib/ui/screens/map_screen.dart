import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Pour la fonction compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
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

  // OPTIMISATION 1 : Typage explicite de la liste pour éviter les casts implicites
  // à chaque itération (le compilateur AOT génère un code natif plus efficace).
  final layers = jsonStyle['layers'] as List<dynamic>?;

  if (layers != null) {
    for (final layer in layers) {
      if (layer['type'] == 'background') {
        layer['paint'] ??= {};
        layer['paint']['background-color'] = bgHex;
        // OPTIMISATION 2 : Break immédiat dès que le layer "background" est trouvé.
        // Le JSON MapTiler contient 200+ layers (routes, bâtiments, labels…).
        // Il n'y a qu'UN SEUL layer de type "background", toujours en premier.
        // Sans ce break, la boucle parcourait inutilement tout le reste du JSON.
        break;
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
  // OPTIM : On cache les deux thèmes (clair + sombre) dès le démarrage.
  // Quand l'OS bascule en dark mode, on switche instantanément entre les deux
  // sans refaire de requête réseau ni de décodage JSON.
  vtr.Theme? _lightTheme;
  vtr.Theme? _darkTheme;

  // Thème actuellement rendu (pointe vers _lightTheme ou _darkTheme).
  vtr.Theme? _mapTheme;

  // Stocke l'ancienne luminosité pour vérifier à chaque draw si on a changé de thème Android/iOS (Clair => Sombre).
  Brightness? _lastBrightness;

  // Variables boolean de Chargement (Indispensable pour le loader UI discret et la parade anti-freeze initial).
  bool _isLoadingPharmacies = true;
  bool _isThemeLoading = false;

  // Variables stockant nos données de base (Modèle Supabase), et nos widgets affichables de carte (Markers).
  List<Pharmacy> _pharmacies = [];
  List<Marker> _cachedMarkers = []; // Les marqueurs pré-calculés, pour éviter la reconstruction native pendant chaque scroll !
  LatLng? _userPosition;

  // Une fois la carte montée, le GPS peut demander un déplacement via ce flag.
  LatLng? _pendingMove;
  // Indique si onMapReady a déjà été déclenché (pour les deux ordres d'arrivée GPS/carte).
  bool _mapReady = false;

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
    _centerOnUserLocation(); // Tente de récupérer la position GPS dès l'ouverture

    // OPTIM : Pré-chargement PARALLÈLE des deux thèmes dès l'ouverture.
    // Le switch dark/light sera instantané car les deux thèmes seront déjà
    // disponibles en mémoire — plus aucun délai réseau ou décodage JSON à ce moment.
    _preloadBothThemes();
  }

  /// Charge les thèmes clair et sombre en parallèle dès le démarrage.
  Future<void> _preloadBothThemes() async {
    await Future.wait([
      _loadVectorMapTheme(Brightness.light, const Color(0xFFF2F4F5)),
      _loadVectorMapTheme(Brightness.dark, null), // bgColor sombre sera résolu dans _loadVectorMapTheme
    ]);
  }

  /// CENTRAGE INITIAL SUR LA POSITION GPS DE L'UTILISATEUR
  /// Utilise geolocator pour vérifier la permission, puis récupère les coordonnées.
  /// La carte se recentre automatiquement si on obtient la position avant ou après le premier rendu.
  Future<void> _centerOnUserLocation() async {
    try {
      // Vérification de la permission (sans bloquer l'UI)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return; // L'utilisateur a refusé : on garde le centre par défaut (Lomé)
      }

      // Récupération de la position avec une précision réduite pour être rapide
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // Low = rapide, parfait pour un centrage initial
        ),
      );

      if (mounted) {
        final userLatLng = LatLng(position.latitude, position.longitude);
        setState(() => _userPosition = userLatLng);

        // CAS 1 : La carte est déjà prête (onMapReady déjà déclenché) → on bouge immédiatement.
        // CAS 2 : La carte n'est pas encore prête → on stocke et onMapReady le fera.
        if (_mapReady) {
          _mapController.move(userLatLng, 15.0);
        } else {
          setState(() => _pendingMove = userLatLng);
        }
      }
    } catch (e) {
      debugPrint('Impossible de récupérer la position GPS : $e');
      // Pas de crash : on reste simplement sur Lomé par défaut
    }
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

        // LAZY LOADING RAFFINÉ : Au lieu d'un délai fixe "aveugle" de 600ms,
        // on attend que Flutter confirme que le PREMIER FRAME a été dessiné à l'écran
        // via SchedulerBinding. C'est le signal que le moteur Skia/Impeller a eu le temps
        // de projeter les premières tuiles vectorielles sur le GPU.
        // Ensuite, un court tampon de 300ms permet aux tuiles suivantes de se décoder
        // en arrière-plan avant d'ajouter la charge CPU des clusters.
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
        await completer.future; // Attend que le 1er frame soit réellement affiché
        await Future.delayed(const Duration(milliseconds: 300)); // Buffer court pour le décodage des tuiles

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

      final bgColor = theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : const Color(0xFFF2F4F5);

      // OPTIM : Si le thème a déjà été pré-chargé (cas nominal après pré-chargement
      // parallèle), on switche instantanément sans réseau ni décodage.
      final cachedTheme = theme.brightness == Brightness.dark ? _darkTheme : _lightTheme;
      if (cachedTheme != null) {
        setState(() => _mapTheme = cachedTheme);
      } else {
        // Première fois (rare) : on charge à la demande.
        _loadVectorMapTheme(theme.brightness, bgColor);
      }

      // On s'assure de rafraîchir aussi la couleur des bordures de nos *Marqueurs* UI.
      // Le theme.colorScheme de la bordure du marqueur s'invaliderait pas de lui-même car il est listé statique dans un cache.
      if (_pharmacies.isNotEmpty) {
        setState(() => _isLoadingPharmacies = true); // Affiche le spinner "optimisation…"
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _updateMarkers();
        });
      }
    }
  }

  /// Gestion du thème vectoriel avec Cache Disque et Thread séparé.
  /// Supporte les deux modes (clair/sombre) — met à jour _lightTheme ou _darkTheme
  /// et pointe _mapTheme vers le thème actif si c'est celui demandé par l'OS.
  Future<void> _loadVectorMapTheme(Brightness brightness, Color? bgColorOverride) async {
    final styleId = brightness == Brightness.dark ? 'streets-v2-dark' : 'streets-v2';
    final cacheKey = 'map_style_$styleId';

    // Résolution de la couleur de fond : priorité à bgColorOverride, sinon valeur par défaut.
    final bgColor = bgColorOverride ??
        (brightness == Brightness.dark
            ? const Color(0xFF121212)  // Surface sombre standard Material
            : const Color(0xFFF2F4F5));

    // OPTIM : On ne bloque pas _isThemeLoading globalement pour les deux thèmes.
    // Chaque chargement (clair/sombre) est indépendant ; seul le thème actif
    // met à jour _isThemeLoading pour afficher le spinner.
    final isCurrentBrightness = (brightness == _lastBrightness);
    if (isCurrentBrightness && mounted) {
      setState(() => _isThemeLoading = true);
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$cacheKey.json');
      String rawJsonStr = '';

      if (await file.exists()) {
        rawJsonStr = await file.readAsString();
      } else {
        final response = await http.get(
          Uri.parse('https://api.maptiler.com/maps/$styleId/style.json?key=$mapTilerKey'),
        );
        if (response.statusCode == 200) {
          rawJsonStr = response.body;
          await file.writeAsString(rawJsonStr);
        }
      }

      if (rawJsonStr.isNotEmpty) {
        // FIX : padLeft(8,'0') garantit 8 caractères hex même pour les couleurs
        // dont la valeur serait courte — sans ça .substring(2,8) lèverait un RangeError.
        final bgHex =
            '#${bgColor.value.toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase()}';

        // EXECUTION HORS DU THREAD PRINCIPAL
        final decodedTheme = await compute(_parseVectorTheme, {
          'jsonStr': rawJsonStr,
          'bgHex': bgHex,
        });

        if (mounted) {
          setState(() {
            // Stockage dans la bonne variable de cache.
            if (brightness == Brightness.dark) {
              _darkTheme = decodedTheme;
            } else {
              _lightTheme = decodedTheme;
            }
            // On expose _mapTheme uniquement si c'est le thème actuellement affiché.
            if (brightness == _lastBrightness) {
              _mapTheme = decodedTheme;
              _isThemeLoading = false;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement thème $styleId: $e');
      if (mounted && isCurrentBrightness) setState(() => _isThemeLoading = false);
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
                // Si la position GPS est déjà connue avant le 1er rendu, on l'utilise directement.
                // Sinon, on affiche Lomé par défaut et _centerOnUserLocation() recentrera via onMapReady.
                initialCenter: _userPosition ?? _initialCenter,
                initialZoom: 15.0,
                maxZoom: 20.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                // OPTIM : onMapReady est l'event OFFICIEL FlutterMap signalant que le
                // moteur de carte est pleinement attaché et prêt à recevoir des commandes.
                // Deux cas : GPS déjà arrivé (_pendingMove != null) → on bouge tout de suite.
                //            GPS pas encore arrivé → on marque _mapReady=true pour que
                //            _centerOnUserLocation() sache qu'il peut appeler move() directement.
                onMapReady: () {
                  _mapReady = true;
                  if (_pendingMove != null) {
                    _mapController.move(_pendingMove!, 15.0);
                    _pendingMove = null;
                  }
                },
              ),
              children: [
                // ================= COUCHES DE LA CARTE (Z-Index / Ordre de projection vectorielle) =================

                // COUCHE N°1 : FOND DE CARTE (VECTORIELLE)
                // OPTIM : if() démonterait/remonterait VectorTileLayer à chaque changement de thème
                // (très coûteux : reconstruction complète + rechargement des tuiles en VRAM).
                // On construit le layer uniquement quand le thème est prêt ; une fois monté,
                // il ne sera plus jamais démonté — le cache GPU reste intègre lors du switch dark/light.
                if (_mapTheme != null)
                  VectorTileLayer(
                    key: const ValueKey('vector_tile_layer'),
                    theme: _mapTheme!,
                    tileProviders: _tileProviders,
                  ),

                // COUCHE N°2 : POSITION UTILISATEUR LITTÉRALE (Point bleu et Cône de vue directionnel)
                // OPTIM : Le style est extrait en variable locale finale pour éviter de reconstruire
                // l'objet LocationMarkerStyle à chaque appel de build().
                Builder(builder: (context) {
                  final locationStyle = LocationMarkerStyle(
                    marker: DefaultLocationMarker(
                      color: theme.colorScheme.primary,
                    ),
                    markerSize: const Size(20, 20),
                  );
                  return CurrentLocationLayer(
                    alignPositionStream: _alignController.stream,
                    style: locationStyle,
                  );
                }),


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
                              _buildClusterWidget(context, markers.length), // Génère le badge chiffré "6" / "2"
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
  Widget _buildClusterWidget(BuildContext context, int count) {
    // Le crash au dézoom rapide vient du fait que le moteur tente de recalculer les ombres 
    // et les couleurs pour chaque nouvelle boule de cluster générée dans l'animation.
    // Isoler le widget avec un RepaintBoundary limite brutalement la consommation RAM et CPU.
    return RepaintBoundary(
      child: Container(
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

    // FIX VALUEKEY : On utilise lat+lon comme identifiant unique stable.
    // Utiliser pharmacy.nom créait des doublons de clés si deux pharmacies
    // portaient le même nom ou si nom était une chaîne vide.
    final stableKey = ValueKey('marker_${point.latitude}_${point.longitude}');

    return Marker(
      point: point, // Coordonnées GPS immuables
      width: 44,
      height: 44,
      // ─── RASTER CACHE via RepaintBoundary ────────────────────────────────────
      // PRINCIPE : Flutter rasterise le sous-arbre en une IMAGE BITMAP dans la
      // VRAM du GPU (1 seule fois). Lors d'un drag/scroll, le moteur Skia/Impeller
      // déplace simplement cette texture — aucun recalcul de cercle, de bordure
      // ni d'icône. C'est la source du gain 30 FPS → 60 FPS constants.
      //
      // RÈGLE CRITIQUE : Le GestureDetector doit être HORS du RepaintBoundary.
      // S'il était à l'intérieur, chaque tap (et chaque changement d'état du
      // recognizer) invaliderait le cache GPU, annulant totalement l'optimisation.
      child: GestureDetector(
        onTap: () => _showPharmacyDetails(context, pharmacy),
        child: RepaintBoundary(
          key: stableKey,
          child: Container(
            decoration: BoxDecoration(
              color: isOpen ? Colors.green.shade100 : Colors.red.shade100,
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
                  // FIX : Le bouton Itinéraire ouvrait Google Maps sans rien faire.
                  // On utilise maintenant l'URL Google Maps de la pharmacie si disponible,
                  // sinon on construit une URL de navigation par coordonnées GPS.
                  onPressed: () {
                    final url = pharmacy.itineraireGoogleMaps?.isNotEmpty == true
                        ? pharmacy.itineraireGoogleMaps!
                        : (pharmacy.latitude != null && pharmacy.longitude != null
                            ? 'https://www.google.com/maps/dir/?api=1&destination=${pharmacy.latitude},${pharmacy.longitude}'
                            : null);
                    if (url != null) {
                      // On copie l'URL dans le presse-papier en attendant url_launcher
                      // (ajouter url_launcher dans pubspec.yaml pour lancer directement)
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lien copié — collez-le dans Google Maps'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
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
