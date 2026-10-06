import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/websocket_service.dart';
import '../../widgets/radar_particle_background.dart';
import '../call/outgoing_call_dialog.dart';

const List<String> kAvailableLanguages = [
  'English',
  'Spanish',
  'French',
  'German',
  'Japanese',
  'Mandarin',
  'Hindi',
];

const Map<String, String> kLanguageFlags = {
  'English': '🇬🇧',
  'Spanish': '🇪🇸',
  'French': '🇫🇷',
  'German': '🇩🇪',
  'Japanese': '🇯🇵',
  'Mandarin': '🇨🇳',
  'Hindi': '🇮🇳',
};

class DiscoveredPeerNode {
  final MatchModel match;
  final double angle;
  final double radiusFraction;
  final int latencyMs;

  DiscoveredPeerNode({
    required this.match,
    required this.angle,
    required this.radiusFraction,
    required this.latencyMs,
  });
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  late List<Particle> _particles;

  bool _isSearching = false;
  int _searchSeconds = 0;
  Timer? _searchTimer;
  StreamSubscription? _wsSubscription;
  bool _isWsConnected = false;

  String _nativeLanguage = 'English';
  String _targetLanguage = 'Spanish';

  // Multi-peer discovered partner map: peerId -> DiscoveredPeerNode
  final Map<String, DiscoveredPeerNode> _discoveredPeers = {};

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rng = math.Random(42);
    _particles = List.generate(40, (i) {
      return Particle(
        radiusFraction: 0.15 + (rng.nextDouble() * 0.82),
        angle: rng.nextDouble() * 2 * math.pi,
        size: 1.0 + rng.nextDouble() * 1.5,
        opacity: 0.25 + rng.nextDouble() * 0.65,
        speed: 0.5 + rng.nextDouble() * 1.5,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (!_isWsConnected) {
      _initSignalingConnection(user.userId);
      _isWsConnected = true;
    }
    if (!_isSearching && _discoveredPeers.isEmpty) {
      final native = user.nativeLanguageName;
      final target = user.targetLanguageName;
      if (native != null && native.isNotEmpty && _nativeLanguage != native) {
        _nativeLanguage = native;
      }
      if (target != null && target.isNotEmpty && _targetLanguage != target) {
        _targetLanguage = target;
      }
    }
  }

  void _initSignalingConnection(String userId) {
    _wsSubscription = WebSocketService.instance.messages.listen((data) {
      final type = data['type'];

      if (type == 'peers_discovered') {
        final List rawPeers = data['peers'] ?? [];
        final angles = [0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 5.9];
        final radii = [0.65, 0.78, 0.60, 0.85, 0.72];
        final newPeers = <String, DiscoveredPeerNode>{};
        int idx = 0;

        for (final p in rawPeers) {
          final peerId = p['peer_id'] ?? '';
          if (peerId.isEmpty) continue;
          final chosenAngle = angles[idx % angles.length];
          final chosenRadius = radii[idx % radii.length];
          idx++;

          final match = MatchModel(
            roomId: p['room_id'] ?? 'room_${userId}_$peerId',
            peerId: peerId,
            peerUsername: p['peer_username'] ?? 'Language Partner',
            peerNativeLang: p['peer_native_lang'] ?? _targetLanguage,
            peerTargetLang: p['peer_target_lang'] ?? _nativeLanguage,
            isInitiator: true,
          );

          newPeers[peerId] = DiscoveredPeerNode(
            match: match,
            angle: chosenAngle,
            radiusFraction: chosenRadius,
            latencyMs: 25 + (math.Random().nextInt(65)),
          );
        }

        setState(() {
          _discoveredPeers.clear();
          _discoveredPeers.addAll(newPeers);
        });

        if (mounted && newPeers.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.person_pin_circle, color: Color(0xFF00E676), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${newPeers.length} Partner(s) on radar! Tap node to call.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF202C33),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (type == 'peer_joined_radar' || type == 'match_found') {
        final p = data['peer'] ?? data;
        final peerId = p['peer_id'] ?? '';

        if (peerId.isNotEmpty && !_discoveredPeers.containsKey(peerId)) {
          final angles = [0.6, 1.4, 2.2, 3.0, 3.8, 4.6, 5.4, 6.0];
          final chosenAngle = angles[_discoveredPeers.length % angles.length];
          final match = MatchModel(
            roomId: p['room_id'] ?? 'room_${userId}_$peerId',
            peerId: peerId,
            peerUsername: p['peer_username'] ?? 'Language Partner',
            peerNativeLang: p['peer_native_lang'] ?? _targetLanguage,
            peerTargetLang: p['peer_target_lang'] ?? _nativeLanguage,
            isInitiator: true,
          );

          setState(() {
            _discoveredPeers[peerId] = DiscoveredPeerNode(
              match: match,
              angle: chosenAngle,
              radiusFraction: 0.72,
              latencyMs: 30 + math.Random().nextInt(60),
            );
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('New partner joined radar: ${match.peerUsername}!'),
                backgroundColor: const Color(0xFF202C33),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (type == 'peer_left_radar') {
        final peerId = data['peer_id'];
        if (peerId != null && _discoveredPeers.containsKey(peerId)) {
          setState(() {
            _discoveredPeers.remove(peerId);
          });
        }
      } else if (type == 'search_cancelled') {
        _stopSearch();
      }
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _searchSeconds = 0;
      _discoveredPeers.clear();
    });

    _searchTimer?.cancel();
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _searchSeconds++);
      }
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    WebSocketService.instance.send({
      'type': 'find_match',
      'user_id': user.userId,
      'username': user.username,
      'native_lang': _nativeLanguage,
      'target_lang': _targetLanguage,
    });
  }

  void _cancelSearch() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    WebSocketService.instance.send({
      'type': 'cancel_search',
      'user_id': user.userId,
    });

    _stopSearch();
  }

  void _stopSearch() {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchSeconds = 0;
        _discoveredPeers.clear();
      });
    }
  }

  void _onDiscoveredNodeTapped(DiscoveredPeerNode peerNode) {
    final match = peerNode.match;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final flag = kLanguageFlags[match.peerNativeLang] ?? '🌐';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00A884),
                ),
                child: Center(
                  child: Text(
                    match.peerUsername.isNotEmpty ? match.peerUsername[0].toUpperCase() : 'P',
                    style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                match.peerUsername,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Native in $flag ${match.peerNativeLang} • Latency ${peerNode.latencyMs}ms',
                style: const TextStyle(color: Color(0xFF8696A0), fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF202C33),
                        foregroundColor: const Color(0xFF00E676),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF2A3942)),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        OutgoingCallDialog.show(
                          context,
                          peerId: match.peerId,
                          peerName: match.peerUsername,
                          targetLanguage: match.peerNativeLang,
                          isAudioOnly: true,
                        );
                      },
                      icon: const Icon(Icons.call, size: 20),
                      label: const Text('Voice Call', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        OutgoingCallDialog.show(
                          context,
                          peerId: match.peerId,
                          peerName: match.peerUsername,
                          targetLanguage: match.peerNativeLang,
                          isAudioOnly: false,
                        );
                      },
                      icon: const Icon(Icons.videocam, size: 20),
                      label: const Text('Video Call', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    WebSocketService.instance.send({
                      'type': 'call_declined',
                      'peer_id': match.peerId,
                      'room_id': match.roomId,
                    });
                    Navigator.pop(ctx);
                    setState(() {
                      _discoveredPeers.remove(match.peerId);
                    });
                  },
                  child: const Text('Decline Match', style: TextStyle(color: Color(0xFF8696A0), fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    _searchTimer?.cancel();
    _wsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            Expanded(
              child: _buildCentralOrbCanvas(),
            ),
            _buildBottomLanguagePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111B21),
        border: Border(bottom: BorderSide(color: Color(0xFF202C33), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.language,
                color: Color(0xFF00E676),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isSearching ? 'Discovery Active' : 'Practice Radar',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF202C33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00A884)),
              ),
              child: Text(
                '${_searchSeconds}s',
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCentralOrbCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _radarController,
          builder: (context, _) {
            final animVal = _radarController.value;

            final centerX = constraints.maxWidth / 2;
            final centerY = constraints.maxHeight / 2;
            final radarRadius = math.min(constraints.maxWidth, constraints.maxHeight) * 0.46;

            final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
            final userInitial = user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U';

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Full Radar Canvas Background
                Positioned.fill(
                  child: CustomPaint(
                    painter: RadarParticlePainter(
                      animationValue: animVal,
                      isSearching: _isSearching,
                      particles: _particles,
                    ),
                  ),
                ),

                // 2. Clean Crisp Tether Lines to all Discovered Partners
                for (final peerNode in _discoveredPeers.values)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TetherLinePainter(
                        centerOffset: Offset(centerX, centerY),
                        targetOffset: Offset(
                          centerX + (radarRadius * peerNode.radiusFraction) * math.cos(peerNode.angle),
                          centerY + (radarRadius * peerNode.radiusFraction) * math.sin(peerNode.angle),
                        ),
                        color: peerNode.latencyMs < 65
                            ? const Color(0xFF25D366)
                            : (peerNode.latencyMs < 130 ? const Color(0xFFFFB020) : const Color(0xFFEF5350)),
                      ),
                    ),
                  ),

                // 3. Center User Node (Positioned accurately at centerX, centerY)
                Positioned(
                  left: centerX - 32,
                  top: centerY - 44,
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00A884),
                          border: Border.all(
                            color: _isSearching ? const Color(0xFF25D366) : const Color(0xFF2A3942),
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            userInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202C33),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2A3942)),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Discovered Partner Nodes (All concurrent peers positioned around the radar)
                for (final peerNode in _discoveredPeers.values)
                  _buildPartnerNode(
                    peerNode: peerNode,
                    centerX: centerX,
                    centerY: centerY,
                    radarRadius: radarRadius,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPartnerNode({
    required DiscoveredPeerNode peerNode,
    required double centerX,
    required double centerY,
    required double radarRadius,
  }) {
    final match = peerNode.match;
    final partnerDistance = radarRadius * peerNode.radiusFraction;
    final partnerOffsetX = partnerDistance * math.cos(peerNode.angle);
    final partnerOffsetY = partnerDistance * math.sin(peerNode.angle);

    final latencyColor = peerNode.latencyMs < 65
        ? const Color(0xFF25D366)
        : (peerNode.latencyMs < 130 ? const Color(0xFFFFB020) : const Color(0xFFEF5350));

    return Positioned(
      left: (centerX + partnerOffsetX) - 48,
      top: (centerY + partnerOffsetY) - 44,
      width: 96,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onDiscoveredNodeTapped(peerNode),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF202C33),
                      border: Border.all(
                        color: const Color(0xFF00E676),
                        width: 2.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        match.peerUsername.isNotEmpty
                            ? match.peerUsername[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF25D366),
                      border: Border.all(color: const Color(0xFF111B21), width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF202C33),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A3942)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            match.peerUsername,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          kLanguageFlags[match.peerNativeLang] ?? '🌐',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: latencyColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${peerNode.latencyMs}ms',
                          style: TextStyle(
                            color: latencyColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildBottomLanguagePanel() {
    final nativeFlag = kLanguageFlags[_nativeLanguage] ?? '🌐';
    final targetFlag = kLanguageFlags[_targetLanguage] ?? '🌐';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F2C34),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF2A3942), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildLanguageCard(
                  label: 'I Speak',
                  flag: nativeFlag,
                  selectedLang: _nativeLanguage,
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => _nativeLanguage = val);
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.setNativeLanguage(val);
                      if (_isSearching) _startSearch();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: IconButton(
                  icon: const Icon(Icons.sync_alt, color: Color(0xFF00E676), size: 20),
                  tooltip: 'Swap Languages',
                  onPressed: () async {
                    final temp = _nativeLanguage;
                    setState(() {
                      _nativeLanguage = _targetLanguage;
                      _targetLanguage = temp;
                    });
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.setNativeLanguage(_nativeLanguage);
                    await authProvider.setTargetLanguage(_targetLanguage);
                    if (_isSearching) _startSearch();
                  },
                ),
              ),
              Expanded(
                child: _buildLanguageCard(
                  label: 'Learning',
                  flag: targetFlag,
                  selectedLang: _targetLanguage,
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => _targetLanguage = val);
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.setTargetLanguage(val);
                      if (_isSearching) _startSearch();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSearching ? const Color(0xFFEA4335) : const Color(0xFF00A884),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (_isSearching) {
                  _cancelSearch();
                } else {
                  _startSearch();
                }
              },
              icon: Icon(
                _isSearching ? Icons.close : Icons.sensors,
                size: 20,
              ),
              label: Text(
                _isSearching ? 'Stop Discovery' : 'Scan for Practice Partners',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required String label,
    required String flag,
    required String selectedLang,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF202C33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3942)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8696A0),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: kAvailableLanguages.contains(selectedLang) ? selectedLang : 'English',
              dropdownColor: const Color(0xFF202C33),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              items: kAvailableLanguages.map((lang) {
                final langFlag = kLanguageFlags[lang] ?? '🌐';
                return DropdownMenuItem(
                  value: lang,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(langFlag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          lang,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TetherLinePainter extends CustomPainter {
  final Offset centerOffset;
  final Offset targetOffset;
  final Color color;

  _TetherLinePainter({
    required this.centerOffset,
    required this.targetOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(centerOffset, targetOffset, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TetherLinePainter oldDelegate) =>
      oldDelegate.centerOffset != centerOffset ||
      oldDelegate.targetOffset != targetOffset ||
      oldDelegate.color != color;
}
