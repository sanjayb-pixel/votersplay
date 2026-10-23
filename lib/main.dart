import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'dart:async';

// ─── Supabase Config ────────────────────────────────────────────────────────
const String _supabaseUrl = 'https://bltnpahunoeyudwyhqur.supabase.co';
const String _supabaseKey = 'sb_publishable_6Gafu7dYSpFeBpyoJEHutQ_MNGzgR7X';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseKey);
  runApp(const MyApp());
}

final _supabase = Supabase.instance.client;
final String _sessionId =
    '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';

// ─── App Root ────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fan Base Election',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: const VotingScreen(),
    );
  }
}

// ─── Candidate Model ─────────────────────────────────────────────────────────
class Candidate {
  final String id;
  final String name;
  final String imageUrl;
  final int votes;

  const Candidate({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.votes = 0,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Voting Screen (MAIN SCREEN: NO VOTE COUNTS SHOWN) ───────────────────────
class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key});
  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  List<Candidate> _candidates = [];
  bool _isLoading = true;
  bool _isVotingEnabled = true;
  int _cooldownSeconds = 0;
  String _errorMessage = '';
  StreamSubscription? _realtimeSub;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  // Load candidates in fixed alphabetical order so main screen never reveals vote standings
  Future<void> _loadCandidates() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('candidates').select().order('name', ascending: true);
      if (!mounted) return;
      setState(() {
        _candidates = (res as List)
            .map((j) => Candidate.fromJson(j as Map<String, dynamic>))
            .toList();
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load candidates. Check your connection.';
        _isLoading = false;
      });
      debugPrint('Load error: $e');
    }
  }

  void _subscribeRealtime() {
    try {
      _realtimeSub = _supabase.from('candidates').stream(primaryKey: ['id']).listen((data) {
        if (!mounted) return;
        setState(() {
          // Keep candidates in fixed alphabetical order on main screen
          _candidates = data
              .map((j) => Candidate.fromJson(j))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
        });
      }, onError: (err) {
        debugPrint('Main screen realtime stream error: $err');
      });
    } catch (e) {
      debugPrint('Realtime setup error: $e');
    }
  }

  Future<void> _castVote(String id, String name) async {
    if (!_isVotingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⏳ Please wait ${_cooldownSeconds}s before voting again',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() {
      _isVotingEnabled = false;
      _cooldownSeconds = 2;
    });

    try {
      final cur = await _supabase.from('candidates').select('votes').eq('id', id).single();
      final newV = ((cur['votes'] as num?)?.toInt() ?? 0) + 1;
      await _supabase.from('candidates').update({'votes': newV}).eq('id', id);
      await _supabase.from('vote_logs').insert({
        'candidate_name': name,
        'session_id': _sessionId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Vote successfully cast for $name!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      debugPrint('Vote error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('❌ Vote failed. Please try again.',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {
        _isVotingEnabled = true;
        _cooldownSeconds = 0;
      });
      return;
    }

    Future.delayed(const Duration(seconds: 1), _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (_cooldownSeconds > 1) {
      setState(() => _cooldownSeconds--);
      Future.delayed(const Duration(seconds: 1), _tick);
    } else {
      setState(() {
        _cooldownSeconds = 0;
        _isVotingEnabled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Ready! You can vote again.', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
    }
  }

  Future<void> _resetVotes() async {
    try {
      await _supabase.from('candidates').update({'votes': 0}).gte('votes', 0);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('🔄 All candidate votes have been reset to 0!'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Reset failed: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _clearAllData() async => _resetVotes();

  void _showAdminLogin() {
    final uc = TextEditingController();
    final pc = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool hide = true;
        return StatefulBuilder(
          builder: (ctx, ss) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 10),
                Text('Admin Dashboard',
                    style: TextStyle(
                        color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter admin credentials to view live vote counts and results.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: uc,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pc,
                  obscureText: hide,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => ss(() => hide = !hide),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (uc.text.trim().toLowerCase() == 'sanjay' &&
                      pc.text.trim().toLowerCase() == 'sanjay@2007') {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => DashboardScreen(
                          onReset: _resetVotes,
                          onClearAllData: _clearAllData,
                        ),
                        transitionsBuilder: (_, a, __, c) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                              .animate(a),
                          child: c,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: const Text('Invalid credentials. Access denied.',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: const Text('Access Dashboard'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Fan Base Election',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Ballot',
            onPressed: _loadCandidates,
            iconSize: 24,
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_customize),
            tooltip: 'Admin Dashboard (Vote Counts)',
            onPressed: _showAdminLogin,
            iconSize: 26,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Ballot Banner (NO VOTE COUNTS)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Text(
                  'Official Voting Ballot',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select your candidate and tap VOTE to cast your ballot',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.how_to_vote, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 5),
                          Text(
                            'Ballot Active',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: !_isVotingEnabled
                          ? Container(
                              key: const ValueKey('cd'),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '⏳ Wait ${_cooldownSeconds}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('rdy'),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '✅ Ready to Vote',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Candidate List (MAIN SCREEN: SHOWS ONLY NAME AND VOTE BUTTON, NO VOTE COUNTS)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off, color: Colors.red.shade300, size: 56),
                            const SizedBox(height: 12),
                            Text(_errorMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadCandidates,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _candidates.isEmpty
                        ? const Center(child: Text('No candidates found on the ballot.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _candidates.length,
                            itemBuilder: (ctx, i) {
                              final c = _candidates[i];
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: Colors.blue.shade50,
                                      backgroundImage: NetworkImage(c.imageUrl),
                                      onBackgroundImageError: (_, __) {},
                                      child: c.imageUrl.isEmpty
                                          ? Text(
                                              c.name.isNotEmpty ? c.name[0] : '?',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Official Candidate',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: SizedBox(
                                      height: 44,
                                      width: 96,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isVotingEnabled ? () => _castVote(c.id, c.name) : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isVotingEnabled
                                              ? Colors.blue.shade700
                                              : Colors.grey.shade400,
                                          foregroundColor: Colors.white,
                                          elevation: _isVotingEnabled ? 3 : 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: _isVotingEnabled
                                            ? const Text(
                                                'VOTE',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  letterSpacing: 1.2,
                                                ),
                                              )
                                            : const Icon(Icons.timer, size: 20),
                                      ),
                                    ),
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

// ─── Dashboard Screen (VOTE COUNTS SHOWN EXCLUSIVELY HERE) ───────────────────
class DashboardScreen extends StatefulWidget {
  final Future<void> Function() onReset;
  final Future<void> Function() onClearAllData;
  const DashboardScreen({super.key, required this.onReset, required this.onClearAllData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Candidate> _candidates = [];
  bool _isLoading = true;
  String _error = '';
  Timer? _pollingTimer;
  StreamSubscription? _streamSub;

  @override
  void initState() {
    super.initState();
    _fetchCandidates();
    _initLiveSync();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchCandidates() async {
    try {
      final res = await _supabase.from('candidates').select();
      if (!mounted) return;
      final list = (res as List)
          .map((j) => Candidate.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.votes.compareTo(a.votes));

      setState(() {
        _candidates = list;
        _isLoading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      if (_candidates.isEmpty) {
        setState(() {
          _error = 'Error fetching results: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _initLiveSync() {
    // 1. Realtime stream subscription
    try {
      _streamSub = _supabase.from('candidates').stream(primaryKey: ['id']).listen((data) {
        if (!mounted) return;
        final list = data.map((j) => Candidate.fromJson(j)).toList()
          ..sort((a, b) => b.votes.compareTo(a.votes));
        setState(() {
          _candidates = list;
          _isLoading = false;
        });
      }, onError: (e) {
        debugPrint('Dashboard realtime stream error (using auto-polling fallback): $e');
      });
    } catch (_) {}

    // 2. Continuous 2-second polling fallback so dashboard ALWAYS stays up-to-date
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchCandidates();
    });
  }

  void _confirmReset(BuildContext ctx) => showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Reset All Votes'),
          content: const Text(
              'Are you sure you want to reset all candidate votes to 0? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.onReset();
                await _fetchCandidates();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset All to 0'),
            ),
          ],
        ),
      );

  void _confirmClear(BuildContext ctx) => showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text('Permanently reset all election votes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.onClearAllData();
                await _fetchCandidates();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All'),
            ),
          ],
        ),
      );

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalVotes = _candidates.fold<int>(0, (sum, c) => sum + c.votes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Vote Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Ballot',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => _confirmReset(context),
            tooltip: 'Reset Votes to 0',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _confirmClear(context),
            tooltip: 'Clear All Data',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Top Summary Cards
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCard('Total Candidates', _candidates.length.toString(), Icons.people,
                      Colors.blue.shade700),
                  Container(height: 40, width: 1, color: Colors.grey.shade300),
                  _statCard('Total Votes Cast', totalVotes.toString(), Icons.how_to_vote,
                      Colors.green.shade700),
                ],
              ),
            ),

            // Live Indicator Banner
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live Vote Counting — Admin Only',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Vote Standings List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty && _candidates.isEmpty
                      ? Center(child: Text(_error))
                      : _candidates.isEmpty
                          ? const Center(child: Text('No vote data recorded yet.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _candidates.length,
                              itemBuilder: (ctx, i) {
                                final c = _candidates[i];
                                final isWinner = i == 0 && c.votes > 0;
                                final percentage =
                                    totalVotes > 0 ? (c.votes / totalVotes * 100) : 0.0;

                                return Card(
                                  elevation: isWinner ? 4 : 2,
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: isWinner
                                        ? BorderSide(color: Colors.amber.shade700, width: 2)
                                        : BorderSide.none,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.blue.shade50,
                                            backgroundImage: NetworkImage(c.imageUrl),
                                            onBackgroundImageError: (_, __) {},
                                            child: c.imageUrl.isEmpty
                                                ? Text(
                                                    c.name.isNotEmpty ? c.name[0] : '?',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          if (isWinner)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade700,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.star,
                                                    color: Colors.white, size: 12),
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Row(
                                        children: [
                                          Text(
                                            '#${i + 1} ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isWinner
                                                  ? Colors.amber.shade900
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              c.name,
                                              style: TextStyle(
                                                fontWeight:
                                                    isWinner ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 15,
                                                color: isWinner ? Colors.amber.shade900 : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: totalVotes > 0 ? (c.votes / totalVotes) : 0,
                                              minHeight: 7,
                                              backgroundColor: Colors.grey.shade200,
                                              valueColor: AlwaysStoppedAnimation(
                                                isWinner
                                                    ? Colors.amber.shade600
                                                    : Colors.blue.shade500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${percentage.toStringAsFixed(1)}% of total votes',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isWinner
                                              ? Colors.amber.shade100
                                              : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                          border: isWinner
                                              ? Border.all(color: Colors.amber.shade700)
                                              : null,
                                        ),
                                        child: Text(
                                          '${c.votes} votes',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isWinner
                                                ? Colors.amber.shade900
                                                : Colors.blue.shade800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
