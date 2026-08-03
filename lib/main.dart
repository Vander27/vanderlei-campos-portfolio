import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'widgets/banner_ad_widget.dart';

/// ================== MODEL ==================

class Video {
  final String title;
  final String videoId;
  final String thumbnail;

  Video({
    required this.title,
    required this.videoId,
    required this.thumbnail,
  });
}

class KoreanYouTubeMovie {
  final String videoId;
  final String title;
  final String thumbnail;
  final String channelTitle;

  KoreanYouTubeMovie({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.channelTitle,
  });
}

/// ================== YOUTUBE SERVICE ==================

Future<List<Video>> fetchPlaylist() async {
  const apiKey = "AIzaSyB0OKS5X4vy7Z5E72d9ehrE9M_h4slvk1E";
  const playlistId = "PLMjX7cp55YlL8DGarNTNbqW1hZsfblNnJ";
  const apresentacaoId = "w5jWwq06CVE"; // vídeo original de apresentação

  final url =
      "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=50&playlistId=$playlistId&key=$apiKey";

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final items = data["items"] as List;

    return items
        .map((item) {
          final snippet = item["snippet"];
          final videoId = snippet["resourceId"]["videoId"];
          final thumbnails = snippet["thumbnails"];

          return Video(
            title: snippet["title"] ?? "",
            videoId: videoId ?? "",
            thumbnail: thumbnails?["high"]?["url"] ??
                thumbnails?["medium"]?["url"] ??
                thumbnails?["default"]?["url"] ?? "",
          );
        })
        // Filtra para NÃO incluir o vídeo de apresentação na lista principal
        .where((video) => video.videoId != apresentacaoId)
        .toList();
  } else {
    throw Exception("Erro ${response.statusCode}: ${response.body}");
  }
}

/// ================== FETCH RECENT VIDEOS ==================
Future<List<Video>> fetchRecentVideos() async {
  final allVideos = await fetchPlaylist();
  // Retorna apenas os 5 primeiros vídeos (mais recentes)
  return allVideos.take(5).toList();
}

/// ================== KOREAN MOVIES SERVICE (YouTube) ==================

const _ytBlockedTerms = [
  'erotic', 'erótico', 'sex', 'sexo', 'xxx', 'porn', 'pornô',
  'nude', 'nudez', 'naked', 'stripper', 'adult', 'adulto',
  '18+', 'hot scene', 'rated r', 'mature',
];

bool _isBlockedContent(String text) {
  final lower = text.toLowerCase();
  return _ytBlockedTerms.any((term) => lower.contains(term));
}

Future<List<KoreanYouTubeMovie>> fetchKoreanMoviesYT(String category) async {
  const apiKey = "AIzaSyB0OKS5X4vy7Z5E72d9ehrE9M_h4slvk1E";

  final Map<String, String> categoryQueries = {
    'Ação': 'filme coreano completo dublado português ação',
    'Romance': 'filme coreano completo dublado português romance',
    'Comédia': 'filme coreano completo dublado português comédia',
    'Infantil': 'filme coreano completo dublado português infantil animação',
    'Terror': 'filme coreano completo dublado português terror suspense',
  };

  final query = categoryQueries[category] ?? 'filme coreano completo dublado português';
  final encodedQuery = Uri.encodeComponent(query);

  final url =
      "https://www.googleapis.com/youtube/v3/search"
      "?part=snippet&type=video&maxResults=20&q=$encodedQuery"
      "&videoDuration=long&videoDefinition=high&safeSearch=strict"
      "&relevanceLanguage=pt&key=$apiKey";

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final items = data["items"] as List;

    return items
        .where((item) {
          final title = (item["snippet"]["title"] ?? "").toString();
          return !_isBlockedContent(title);
        })
        .map((item) {
          final snippet = item["snippet"];
          return KoreanYouTubeMovie(
            videoId: item["id"]["videoId"] ?? "",
            title: snippet["title"] ?? "Sem título",
            thumbnail: snippet["thumbnails"]["high"]?["url"] ??
                snippet["thumbnails"]["medium"]?["url"] ??
                snippet["thumbnails"]["default"]?["url"] ?? "",
            channelTitle: snippet["channelTitle"] ?? "",
          );
        })
        .toList();
  } else {
    throw Exception("Erro ao buscar filmes no YouTube: ${response.statusCode}");
  }
}

/// ================== FAVORITES STORAGE ==================

Future<void> saveFavorite(String videoId) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> favorites = prefs.getStringList("favorites") ?? [];

  if (!favorites.contains(videoId)) {
    favorites.add(videoId);
    await prefs.setStringList("favorites", favorites);
  }
}

Future<void> removeFavorite(String videoId) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> favorites = prefs.getStringList("favorites") ?? [];

  favorites.remove(videoId);
  await prefs.setStringList("favorites", favorites);
}

Future<List<String>> getFavorites() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList("favorites") ?? [];
}

Future<void> saveWatchedVideo(String videoId) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> watched = prefs.getStringList("watched_videos") ?? [];

  if (!watched.contains(videoId)) {
    watched.add(videoId);
    await prefs.setStringList("watched_videos", watched);
  }
}

Future<List<String>> getWatchedVideos() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList("watched_videos") ?? [];
}

Future<void> removeWatchedVideo(String videoId) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> watched = prefs.getStringList("watched_videos") ?? [];
  watched.remove(videoId);
  await prefs.setStringList("watched_videos", watched);
}

/// ================== BANNER HEADER ==================
class BannerHeader extends StatelessWidget {
  const BannerHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = width < 600 ? 160.0 : 240.0;
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Image.asset(
            'assets/banner_macefo.png',
            height: height,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// ================== MAIN ==================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  AdService.initialize();
  PurchaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GalleryScreen(),
    );
  }
}

/// ================== GALLERY ==================

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late YoutubePlayerController _controller;
  late final NewVersionPlus _newVersion;

  @override
  void initState() {
    super.initState();
    _newVersion = NewVersionPlus(androidId: 'com.macefo.mini');
    _controller = YoutubePlayerController(
      initialVideoId: 'w5jWwq06CVE',
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        disableDragSeek: false,
        mute: false,
        isLive: false,
        forceHD: false,
        enableCaption: false,
        hideControls: false,
        hideThumbnail: false,
        loop: false,
        controlsVisibleAtStart: false,
        useHybridComposition: true,
      ),
    );
    // Bloqueia rotação de tela apenas nesta página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    });
    // Listener para fullscreen: libera rotação quando entra em tela cheia
    _controller.addListener(() {
      if (_controller.value.isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });

    PurchaseService.onPurchaseSuccess = () {
      if (mounted) setState(() {});
    };
  }

  Future<void> _checkForUpdates({bool manual = false}) async {
    try {
      final status = await _newVersion.getVersionStatus();
      if (!mounted) return;

      if (status != null && status.canUpdate) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Nova versão disponível'),
              content: Text(
                'Versão atual: ${status.localVersion}\n'
                'Nova versão: ${status.storeVersion}\n\n'
                'Deseja atualizar agora?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Depois'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _newVersion.launchAppStore(status.appStoreLink);
                  },
                  child: const Text('Atualizar'),
                ),
              ],
            );
          },
        );
        return;
      }
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já está na versão mais recente.')),
        );
      }
    } catch (_) {
      if (!mounted || !manual) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível verificar atualização.')),
      );
    }
  }

  void _showRemoveAdsDialog() {
    final product = PurchaseService.removeAdsProduct;
    final priceText = product?.price ?? 'R\$ 2,50';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFFFF8EE),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.block, color: Colors.red.shade700, size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Remover Anúncios',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$priceText — Pagamento único!',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                _dialogBullet('Remove todos os anúncios do app'),
                const SizedBox(height: 6),
                _dialogBullet('Pagamento único, sem assinatura'),
                const SizedBox(height: 6),
                _dialogBullet('Válido para este aparelho'),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        'Vinculado a este dispositivo. Em caso de troca de aparelho, será necessário adquirir novamente.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        if (product != null) {
                          await PurchaseService.buyRemoveAds();
                        } else {
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: const Color(0xFFFFF8EE),
                                title: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                                    const SizedBox(width: 10),
                                    const Text('Em breve',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                content: const Text(
                                  'A compra estará disponível em breve. Estamos finalizando a configuração. Obrigado pela paciência!',
                                  style: TextStyle(fontSize: 15),
                                ),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Entendi'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.shopping_cart, size: 20),
                      label: Text(
                        'Comprar $priceText',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogBullet(String text) {
    return Row(
      children: [
        const Text('✅ ', style: TextStyle(fontSize: 15)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Restaura orientação padrão ao sair da tela
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0822),
      bottomNavigationBar: const BannerAdWidget(),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Stack(
            children: [
              const BannerHeader(),
              if (!AdService.adsRemoved)
                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      color: const Color(0xFF232A4D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) async {
                        if (value == 'remove_ads') {
                          _showRemoveAdsDialog();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'remove_ads',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Remover Anúncios',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 4),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SizedBox(
                        width: constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : 560,
                        height: constraints.maxWidth < 600
                            ? constraints.maxWidth * 9 / 16
                            : 315,
                        child: YoutubePlayer(
                          controller: _controller,
                          showVideoProgressIndicator: true,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                          gradient: LinearGradient(
                            colors: [Color(0xFF00FFD0), Color(0xFF6A00FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00FFD0).withOpacity(0.5),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Aproveite o conteúdo exclusivo Macefo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // ====== RECOMENDAÇÃO MACEFO ======
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedGlow(),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 8, left: 8, right: 8),
                              child: Text(
                                'Recomendação Macefo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                _GalleryCard(
                  title: 'Mini Série',
                  icon: Icons.video_collection,
                  onTap: () {
                    AdService.onAction();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlaylistScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _GalleryCard(
                  title: 'Favoritos',
                  icon: Icons.star,
                  onTap: () {
                    AdService.onAction();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FavoritesScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _GalleryCard(
                  title: 'Últimos Vídeos Adicionados',
                  icon: Icons.new_releases,
                  onTap: () {
                    AdService.onAction();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecentVideosScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _GalleryCard(
                  title: 'Bônus: Filmes Asiáticos',
                  icon: Icons.movie,
                  onTap: () {
                    AdService.onAction();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KoreanMovieScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔥 WIDGET QUE ESTAVA FALTANDO

// ignore: unused_element
class _GalleryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _GalleryCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF232A4D),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================== PLAYLIST ==================

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late Future<List<Video>> _videosFuture;
  List<String> favoriteIds = [];
  List<String> watchedIds = [];

  @override
  void initState() {
    super.initState();
    _videosFuture = fetchPlaylist();
    loadFavorites();
    loadWatchedVideos();
  }

  Future<void> loadFavorites() async {
    final ids = await getFavorites();
    setState(() {
      favoriteIds = ids;
    });
  }

  void toggleFavorite(String videoId) async {
    if (favoriteIds.contains(videoId)) {
      await removeFavorite(videoId);
      favoriteIds.remove(videoId);
    } else {
      await saveFavorite(videoId);
      favoriteIds.add(videoId);
    }
    setState(() {});
  }

  Future<void> loadWatchedVideos() async {
    final ids = await getWatchedVideos();
    setState(() {
      watchedIds = ids;
    });
  }

  Future<void> unmarkAsWatched(String videoId) async {
    await removeWatchedVideo(videoId);
    await loadWatchedVideos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vídeo desmarcado como assistido')),
    );
  }

  Future<void> toggleWatchedStatus(String videoId, bool isWatched) async {
    if (isWatched) {
      await removeWatchedVideo(videoId);
    } else {
      await saveWatchedVideo(videoId);
    }
    await loadWatchedVideos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWatched
              ? 'Vídeo desmarcado como assistido'
              : 'Vídeo marcado como assistido',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0822),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const BannerHeader(),
          Expanded(
            child: FutureBuilder<List<Video>>(
              future: _videosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Erro ao carregar vídeos:\n${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _videosFuture = fetchPlaylist();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Tentar novamente"),
                        ),
                      ],
                    ),
                  );
                }
                final videos = snapshot.data ?? [];
                if (videos.isEmpty) {
                  return const Center(
                    child: Text(
                      "Nenhum vídeo encontrado",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(0),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final isFavorite = favoriteIds.contains(video.videoId);
                    final isWatched = watchedIds.contains(video.videoId);
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(video: video),
                          ),
                        );
                        if (!mounted) return;
                        await loadFavorites();
                        await loadWatchedVideos();
                      },
                      onLongPress: () =>
                          toggleWatchedStatus(video.videoId, isWatched),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: isFavorite
                                ? [Color(0xFF00FFD0), Color(0xFF6A00FF)]
                                : [Color(0xFF232A4D), Color(0xFF232A4D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Hero(
                              tag: video.videoId,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24)),
                                    child: Image.network(
                                      video.thumbnail,
                                      height: isWide ? 260 : 220,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (isWatched)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: GestureDetector(
                                        onTap: () =>
                                            unmarkAsWatched(video.videoId),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.7),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: Colors.greenAccent,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Assistido',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                video.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.star : Icons.star_border,
                                  color:
                                      isFavorite ? Colors.amber : Colors.white,
                                ),
                                onPressed: () => toggleFavorite(video.videoId),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ================== VIDEO PLAYER ==================

class VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  int _savedPositionSeconds = 0;
  int _lastPersistedSecond = -1;
  bool _resumePromptShown = false;
  bool _progressLoaded = false;
  bool _isResumeDialogOpen = false;
  bool _showOverlayControls = true;
  bool _wasPlaying = false;
  int _lastUiSecond = -1;
  bool _endStateHandled = false;
  Timer? _controlsHideTimer;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true),
    );
    _controller.addListener(_handlePlayerUpdates);
    _loadSavedProgress();
  }

  String get _progressKey => 'video_progress_${widget.video.videoId}';

  Future<void> _loadSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _savedPositionSeconds = prefs.getInt(_progressKey) ?? 0;
    _progressLoaded = true;
    if (mounted) setState(() {});
  }

  Future<void> _saveProgress(Duration position) async {
    final second = position.inSeconds;
    if (second < 0) return;
    if (_lastPersistedSecond >= 0 &&
        (second - _lastPersistedSecond).abs() < 2) {
      return;
    }
    _lastPersistedSecond = second;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressKey, second);
  }

  Future<void> _clearProgress() async {
    _savedPositionSeconds = 0;
    _lastPersistedSecond = -1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey);
  }

  Future<void> _markVideoAsWatched() async {
    await saveWatchedVideo(widget.video.videoId);
  }

  Future<void> _handleVideoEnded() async {
    await _markVideoAsWatched();
    await _clearProgress();
    _cancelAutoHideControlsTimer();
    _controller.seekTo(Duration.zero);
    _controller.pause();
    if (mounted && !_showOverlayControls) {
      setState(() => _showOverlayControls = true);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }

  void _handlePlayerUpdates() {
    if (!mounted) return;
    if (!_progressLoaded) return;
    if (_isResumeDialogOpen) return;

    final value = _controller.value;

    final currentSecond = value.position.inSeconds;
    if (currentSecond != _lastUiSecond) {
      _lastUiSecond = currentSecond;
      setState(() {});
    }

    if (value.isPlaying != _wasPlaying) {
      _wasPlaying = value.isPlaying;
      if (value.isPlaying) {
        _startAutoHideControlsTimer();
      } else {
        _cancelAutoHideControlsTimer();
        if (!_showOverlayControls) {
          setState(() => _showOverlayControls = true);
        }
      }
    }

    if (!_resumePromptShown && value.isReady && _savedPositionSeconds >= 5) {
      _resumePromptShown = true;
      _isResumeDialogOpen = true;
      _controller.pause();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showResumeDialog();
        }
      });
      return;
    }

    if (value.playerState == PlayerState.ended) {
      if (!_endStateHandled) {
        _endStateHandled = true;
        unawaited(_handleVideoEnded());
      }
      return;
    }

    if (_endStateHandled) {
      _endStateHandled = false;
    }

    _saveProgress(value.position);
  }

  Future<void> _showResumeDialog() async {
    final continueFromWhereStopped = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Continuar vídeo?'),
          content: const Text(
              'Encontramos seu progresso. Deseja continuar de onde parou?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Do início'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (continueFromWhereStopped == true) {
      _controller.seekTo(Duration(seconds: _savedPositionSeconds));
      _controller.play();
      _isResumeDialogOpen = false;
      return;
    }

    _controller.seekTo(Duration.zero);
    await _clearProgress();
    _controller.play();
    _isResumeDialogOpen = false;
  }

  void _seekBySeconds(int seconds) {
    _showControlsTemporarily();
    final current = _controller.value.position;
    final target = current + Duration(seconds: seconds);
    _controller.seekTo(target.isNegative ? Duration.zero : target);
  }

  void _togglePlayPause() {
    _showControlsTemporarily();
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    if (mounted) setState(() {});
  }

  void _showControlsTemporarily() {
    if (!_showOverlayControls) {
      setState(() => _showOverlayControls = true);
    }
    _startAutoHideControlsTimer();
  }

  void _startAutoHideControlsTimer() {
    _cancelAutoHideControlsTimer();
    if (!_controller.value.isPlaying) return;

    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (!_controller.value.isPlaying) return;
      setState(() => _showOverlayControls = false);
    });
  }

  void _cancelAutoHideControlsTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  @override
  void dispose() {
    _cancelAutoHideControlsTimer();
    _saveProgress(_controller.value.position);
    _controller.removeListener(_handlePlayerUpdates);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _enterFullScreen() {
    setState(() => _isFullScreen = true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullScreen() {
    setState(() => _isFullScreen = false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _toggleFullScreen() {
    if (_isFullScreen) {
      _exitFullScreen();
    } else {
      _enterFullScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: const Color(0xFF0A0822),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _isFullScreen
                      ? _buildPlayerStack()
                      : AspectRatio(
                          aspectRatio: 9 / 16,
                          child: _buildPlayerStack(),
                        ),
                  ),
                  if (!_isFullScreen)
                  Container(
                    height: 36,
                    width: double.infinity,
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.metadata.duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          color: Colors.white,
                          onPressed: _toggleFullScreen,
                          icon: const Icon(Icons.fullscreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStack() {
    return Hero(
      tag: widget.video.videoId,
      child: Stack(
        fit: StackFit.expand,
        children: [
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _showControlsTemporarily,
                  onDoubleTap: () => _seekBySeconds(-10),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _showControlsTemporarily,
                  onDoubleTap: () => _seekBySeconds(10),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.center,
            child: IgnorePointer(
              ignoring: !_showOverlayControls,
              child: AnimatedOpacity(
                opacity: _showOverlayControls ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 38,
                      splashRadius: 28,
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: () => _seekBySeconds(-10),
                      icon: const Icon(Icons.replay_10),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 46,
                      splashRadius: 30,
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 38,
                      splashRadius: 28,
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                      onPressed: () => _seekBySeconds(10),
                      icon: const Icon(Icons.forward_10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isFullScreen)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showOverlayControls ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.metadata.duration)}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        iconSize: 24,
                        padding: EdgeInsets.zero,
                        color: Colors.white,
                        onPressed: _toggleFullScreen,
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ================== UPDATE CHECK SCREEN ==================

class UpdateCheckScreen extends StatefulWidget {
  const UpdateCheckScreen({super.key});

  @override
  State<UpdateCheckScreen> createState() => _UpdateCheckScreenState();
}

class _UpdateCheckScreenState extends State<UpdateCheckScreen> {
  late NewVersionPlus _newVersion;
  bool _loading = true;
  String? _currentVersion;
  String? _newVersion_;
  bool _hasUpdate = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _newVersion = NewVersionPlus(androidId: 'com.macefo.mini');
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = packageInfo.version;
      });

      final status = await _newVersion.getVersionStatus();
      if (!mounted) return;

      if (status != null) {
        setState(() {
          _newVersion_ = status.storeVersion;
          _hasUpdate = status.canUpdate;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao verificar atualização: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _goToPlayStore() async {
    try {
      final status = await _newVersion.getVersionStatus();
      if (status != null && mounted) {
        _newVersion.launchAppStore(status.appStoreLink);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir Play Store: $e')),
      );
    }
  }

  Future<void> _shareApp() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await Share.share(
        'Confira o aplicativo MACEFO! Assista a vídeos exclusivos e conteúdo de qualidade.\n\nhttps://play.google.com/store/apps/details?id=${packageInfo.packageName}',
        subject: 'Conheça o app MACEFO',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao compartilhar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0822),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const BannerHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() => _loading = true);
                                  _checkVersion();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasUpdate) ...[
                              Icon(
                                Icons.system_update,
                                color: const Color(0xFF00FFD0),
                                size: 80,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Uma nova versão está disponível!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: const Color(0xFF232A4D),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Color(0xFF00FFD0),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Informações da Atualização',
                                          style: TextStyle(
                                            color: Color(0xFF00FFD0),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Versão Atual: $_currentVersion',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Nova Versão: $_newVersion_',
                                      style: const TextStyle(
                                        color: Color(0xFF00FFD0),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _goToPlayStore,
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text(
                                    'Ir para Play Store',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF00FFD0),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                                size: 80,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Você está atualizado!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: const Color(0xFF232A4D),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.greenAccent,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Versão Atual: $_currentVersion',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Esta é a versão mais recente disponível',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _shareApp,
                                icon: const Icon(Icons.share),
                                label: const Text(
                                  'Compartilhar com Amigos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF00FFD0),
                                  side: const BorderSide(
                                    color: Color(0xFF00FFD0),
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// ================== KOREAN MOVIE SCREEN (YouTube) ==================

class KoreanMovieScreen extends StatefulWidget {
  const KoreanMovieScreen({super.key});

  @override
  State<KoreanMovieScreen> createState() => _KoreanMovieScreenState();
}

class _KoreanMovieScreenState extends State<KoreanMovieScreen> {
  late Future<List<KoreanYouTubeMovie>> _moviesFuture;
  String _selectedCategory = 'Ação';
  final List<String> categories = ['Ação', 'Romance', 'Comédia', 'Infantil', 'Terror'];
  List<String> _watchedIds = [];
  Set<String> _inProgressIds = {};

  @override
  void initState() {
    super.initState();
    _moviesFuture = fetchKoreanMoviesYT(_selectedCategory);
    _loadWatchStatus();
  }

  Future<void> _loadWatchStatus() async {
    final watched = await getWatchedVideos();
    final prefs = await SharedPreferences.getInstance();
    final inProgress = <String>{};
    for (final id in (prefs.getKeys().where((k) => k.startsWith('video_progress_')))) {
      final vid = id.replaceFirst('video_progress_', '');
      final sec = prefs.getInt(id) ?? 0;
      if (sec >= 5 && !watched.contains(vid)) {
        inProgress.add(vid);
      }
    }
    if (mounted) {
      setState(() {
        _watchedIds = watched;
        _inProgressIds = inProgress;
      });
    }
  }

  void _changeCategory(String newCategory) {
    setState(() {
      _selectedCategory = newCategory;
      _moviesFuture = fetchKoreanMoviesYT(newCategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0822),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const BannerHeader(),
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Text(
              'Bônus: Filmes Asiáticos Dublados',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  final isSelected = category == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: GestureDetector(
                      onTap: () => _changeCategory(category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00FFD0)
                              : const Color(0xFF232A4D),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(color: Colors.white30, width: 1),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<KoreanYouTubeMovie>>(
              future: _moviesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Erro ao carregar filmes: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {
                              _moviesFuture = fetchKoreanMoviesYT(_selectedCategory);
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final movies = snapshot.data ?? [];
                if (movies.isEmpty) {
                  return const Center(
                    child: Text(
                      "Nenhum filme encontrado nesta categoria",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(
                              video: Video(
                                title: movie.title,
                                videoId: movie.videoId,
                                thumbnail: movie.thumbnail,
                              ),
                            ),
                          ),
                        );
                        _loadWatchStatus();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: const Color(0xFF232A4D),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              child: Stack(
                                children: [
                                  Image.network(
                                    movie.thumbnail,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[800],
                                        child: Center(
                                          child: Icon(Icons.image_not_supported,
                                              color: Colors.grey[400], size: 48),
                                        ),
                                      );
                                    },
                                  ),
                                  if (_watchedIds.contains(movie.videoId))
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.visibility, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('Assistido', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (_inProgressIds.contains(movie.videoId))
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('Assistindo', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    movie.channelTitle,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00FFD0),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_circle_fill, color: Colors.black, size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              'Assistir no App',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Dublado PT-BR',
                                          style: TextStyle(
                                            color: Colors.lightBlueAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RecentVideosScreen extends StatefulWidget {
  const RecentVideosScreen({super.key});

  @override
  State<RecentVideosScreen> createState() => _RecentVideosScreenState();
}

class _RecentVideosScreenState extends State<RecentVideosScreen> {
  late Future<List<Video>> _videosFuture;
  List<String> favoriteIds = [];
  List<String> watchedIds = [];

  @override
  void initState() {
    super.initState();
    _videosFuture = fetchRecentVideos();
    loadFavorites();
    loadWatchedVideos();
  }

  Future<void> loadFavorites() async {
    final ids = await getFavorites();
    setState(() {
      favoriteIds = ids;
    });
  }

  void toggleFavorite(String videoId) async {
    if (favoriteIds.contains(videoId)) {
      await removeFavorite(videoId);
      favoriteIds.remove(videoId);
    } else {
      await saveFavorite(videoId);
      favoriteIds.add(videoId);
    }
    setState(() {});
  }

  Future<void> loadWatchedVideos() async {
    final ids = await getWatchedVideos();
    setState(() {
      watchedIds = ids;
    });
  }

  Future<void> unmarkAsWatched(String videoId) async {
    await removeWatchedVideo(videoId);
    await loadWatchedVideos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vídeo desmarcado como assistido')),
    );
  }

  Future<void> toggleWatchedStatus(String videoId, bool isWatched) async {
    if (isWatched) {
      await removeWatchedVideo(videoId);
    } else {
      await saveWatchedVideo(videoId);
    }
    await loadWatchedVideos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWatched
              ? 'Vídeo desmarcado como assistido'
              : 'Vídeo marcado como assistido',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0822),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const BannerHeader(),
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Text(
              'Últimos Vídeos Adicionados',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Video>>(
              future: _videosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "Erro ao carregar vídeos",
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }
                final videos = snapshot.data ?? [];
                if (videos.isEmpty) {
                  return const Center(
                    child: Text(
                      "Nenhum vídeo encontrado",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(0),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final isFavorite = favoriteIds.contains(video.videoId);
                    final isWatched = watchedIds.contains(video.videoId);
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(video: video),
                          ),
                        );
                        if (!mounted) return;
                        await loadFavorites();
                        await loadWatchedVideos();
                      },
                      onLongPress: () =>
                          toggleWatchedStatus(video.videoId, isWatched),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: isFavorite
                                ? [Color(0xFF00FFD0), Color(0xFF6A00FF)]
                                : [Color(0xFF232A4D), Color(0xFF232A4D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Hero(
                              tag: video.videoId,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24)),
                                    child: Image.network(
                                      video.thumbnail,
                                      height: isWide ? 260 : 220,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (isWatched)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: GestureDetector(
                                        onTap: () =>
                                            unmarkAsWatched(video.videoId),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.7),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: Colors.greenAccent,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Assistido',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                video.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.star : Icons.star_border,
                                  color:
                                      isFavorite ? Colors.amber : Colors.white,
                                ),
                                onPressed: () => toggleFavorite(video.videoId),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ================== FAVORITES ==================

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool loading = true;
  List<Video> favoriteVideos = [];
  List<String> watchedIds = [];

  @override
  void initState() {
    super.initState();
    loadFavorites();
    loadWatchedVideos();
  }

  Future<void> loadWatchedVideos() async {
    final ids = await getWatchedVideos();
    setState(() {
      watchedIds = ids;
    });
  }

  Future<List<Video>> fetchAllVideos() async {
    try {
      return await fetchPlaylist();
    } catch (_) {
      return [];
    }
  }

  Future<void> loadFavorites() async {
    setState(() => loading = true);
    final favIds = await getFavorites();
    final allVideos = await fetchAllVideos();
    favoriteVideos =
        allVideos.where((v) => favIds.contains(v.videoId)).toList();
    setState(() => loading = false);
  }

  Future<void> unmarkAsWatched(String videoId) async {
    await removeWatchedVideo(videoId);
    await loadWatchedVideos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vídeo desmarcado como assistido')),
    );
  }

  Future<void> toggleWatchedStatus(String videoId, bool isWatched) async {
    if (isWatched) {
      await removeWatchedVideo(videoId);
    } else {
      await saveWatchedVideo(videoId);
    }
    await loadWatchedVideos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWatched
              ? 'Vídeo desmarcado como assistido'
              : 'Vídeo marcado como assistido',
        ),
      ),
    );
  }

  void removeFavoriteAndRefresh(String videoId) async {
    await removeFavorite(videoId);
    await loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0822),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const BannerHeader(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : favoriteVideos.isEmpty
                    ? const Center(
                        child: Text('Nenhum favorito',
                            style: TextStyle(color: Colors.white)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(0),
                        itemCount: favoriteVideos.length,
                        itemBuilder: (context, index) {
                          final video = favoriteVideos[index];
                          final isWatched = watchedIds.contains(video.videoId);
                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      VideoPlayerScreen(video: video),
                                ),
                              );
                              if (!mounted) return;
                              await loadFavorites();
                              await loadWatchedVideos();
                            },
                            onLongPress: () =>
                                toggleWatchedStatus(video.videoId, isWatched),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF232A4D),
                                    Color(0xFF232A4D)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Hero(
                                    tag: video.videoId,
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(24)),
                                          child: Image.network(
                                            video.thumbnail,
                                            height: isWide ? 260 : 220,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        if (isWatched)
                                          Positioned(
                                            top: 10,
                                            left: 10,
                                            child: GestureDetector(
                                              onTap: () => unmarkAsWatched(
                                                  video.videoId),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.7),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: 16,
                                                      color: Colors.greenAccent,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Assistido',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      video.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => removeFavoriteAndRefresh(
                                          video.videoId),
                                    ),
                                  ),
                                ],
                              ),
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

// ====== WIDGET DE GLOW ANIMADO FUTURISTA ======
class AnimatedGlow extends StatefulWidget {
  const AnimatedGlow({Key? key}) : super(key: key);

  @override
  State<AnimatedGlow> createState() => _AnimatedGlowState();
}

class _AnimatedGlowState extends State<AnimatedGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(Color(0xFF00FFD0), Color(0xFF6A00FF),
                        _controller.value)!
                    .withOpacity(0.25),
                blurRadius: 64 * (0.7 + 0.3 * _controller.value),
                spreadRadius: 24 * (0.7 + 0.3 * _controller.value),
              ),
            ],
          ),
        );
      },
    );
  }
}
