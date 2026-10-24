import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'dart:async';
import 'user_credentials.dart';

// ─── Supabase Config ────────────────────────────────────────────────────────
const String _supabaseUrl = 'https://bltnpahunoeyudwyhqur.supabase.co';
const String _supabaseKey = 'sb_publishable_6Gafu7dYSpFeBpyoJEHutQ_MNGzgR7X';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initError;
  try {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  } catch (e) {
    initError = e.toString();
    debugPrint('❌ Supabase init failed: $e');
  }
  runApp(MyApp(initError: initError));
}

final _supabase = Supabase.instance.client;
final String _sessionId =
    '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';

// ─── App Root ────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  final String? initError;
  const MyApp({super.key, this.initError});

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
      home: initError != null ? _ErrorScreen(error: initError!) : const UserLoginScreen(),
    );
  }
}

// Shows a clear error instead of a blank white screen
class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 64),
              const SizedBox(height: 16),
              Text(
                '⚠️ Supabase Initialization Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Check that your Supabase URL and anon key are correct.\nThe anon key should start with "eyJ..."',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Candidate Image Fallback Map ────────────────────────────────────────────
// Provides guaranteed working images for candidates whose Supabase image_url is empty/broken.
const Map<String, String> _candidateImages = {
  'ajith kumar':
      'https://upload.wikimedia.org/wikipedia/commons/5/50/Ajith_kumar_2019.jpg',
  'sai pallavi':
      'https://upload.wikimedia.org/wikipedia/commons/e/ee/Sai_Pallavi_at_Mca-pre-release-event.jpg',
};

String _resolveImage(String? rawUrl, String name) {
  final key = name.trim().toLowerCase();
  if (_candidateImages.containsKey(key)) {
    return _candidateImages[key]!;
  }
  if (rawUrl != null && rawUrl.trim().isNotEmpty) return rawUrl.trim();
  return '';
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
    final name = json['name']?.toString() ?? '';
    final rawUrl = json['image_url']?.toString();
    return Candidate(
      id: json['id']?.toString() ?? '',
      name: name,
      imageUrl: _resolveImage(rawUrl, name),
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Candidate Avatar Widget ─────────────────────────────────────────────────
// StatelessWidget using Image.network + errorBuilder — NO setState, NO frame crash.
class _CandidateAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double radius;
  final bool showWinnerBadge;

  const _CandidateAvatar({
    required this.imageUrl,
    required this.name,
    this.radius = 26,
    this.showWinnerBadge = false,
  });

  Widget _initials(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue.shade50,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.76,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    if (imageUrl.isEmpty) return _initials(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue.shade50,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // errorBuilder runs OUTSIDE the frame — no setState crash
          errorBuilder: (_, __, ___) => _initials(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final av = _avatar(context);
    if (!showWinnerBadge) return av;
    return Stack(
      children: [
        av,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 12),
          ),
        ),
      ],
    );
  }
}

// ─── Student / Voter Login Screen ──────────────────────────────────────────
class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _errorText = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final name = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (name.isEmpty || pass.isEmpty) {
      setState(() {
        _errorText = 'Please enter both your Student Name and Register Number.';
      });
      return;
    }

    if (validateVoterCredentials(name, pass)) {
      setState(() => _errorText = '');
      final cleanName = name.toUpperCase();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VotingScreen(
            loggedInUser: cleanName,
            regNo: pass,
          ),
        ),
      );
    } else {
      setState(() {
        _errorText = 'Invalid Student Name or Password (Register No). Please check and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.indigo.shade800,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.how_to_vote,
                          color: Colors.blue.shade700,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Voter Authentication',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fan Base Election Portal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_errorText.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorText,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        controller: _usernameController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Student Name (Username)',
                          hintText: 'e.g. ABINAYA D',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Register Number (Password)',
                          hintText: 'e.g. 730925106001',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'LOGIN TO VOTE',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Note: Username is your name in the list, password is your 12-digit register number.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Voting Screen (MAIN SCREEN: NO VOTE COUNTS SHOWN) ───────────────────────
class VotingScreen extends StatefulWidget {
  final String? loggedInUser;
  final String? regNo;
  const VotingScreen({super.key, this.loggedInUser, this.regNo});
  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  List<Candidate> _candidates = [];
  bool _isLoading = true;
  bool _isCheckingVoteStatus = false;
  bool _hasVoted = false;
  String _votedCandidateName = '';
  bool _isVotingEnabled = true;
  String _errorMessage = '';
  StreamSubscription? _realtimeSub;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _patchCandidateImages(); // Fix missing images in Supabase DB
    _checkIfUserAlreadyVoted();
    _loadCandidates();
    _subscribeRealtime();
  }

  /// Checks if this student has already cast their single vote in the CURRENT election round.
  /// Ignores any votes cast prior to the latest "Clear All / Reset" epoch.
  Future<void> _checkIfUserAlreadyVoted() async {
    final voterKey = widget.regNo ?? widget.loggedInUser;
    if (voterKey == null || voterKey.isEmpty) return;

    setState(() => _isCheckingVoteStatus = true);
    try {
      // 1. Get the current election start time (stored in Joseph Vijay's created_at)
      final epochRes = await _supabase
          .from('candidates')
          .select('created_at')
          .eq('name', 'Joseph Vijay')
          .maybeSingle();

      final epochString = epochRes?['created_at']?.toString() ?? '1970-01-01T00:00:00Z';

      // 2. Only consider votes that happened AFTER this election start time
      final rows = await _supabase
          .from('vote_logs')
          .select('candidate_name')
          .eq('session_id', voterKey)
          .gte('voted_at', epochString);

      if (!mounted) return;
      if (rows.isNotEmpty) {
        final candName = rows.first['candidate_name']?.toString() ?? '';
        setState(() {
          _hasVoted = true;
          _votedCandidateName = candName;
          _isVotingEnabled = false;
          _isCheckingVoteStatus = false;
        });
      } else {
        setState(() {
          _hasVoted = false;
          _votedCandidateName = '';
          _isVotingEnabled = true;
          _isCheckingVoteStatus = false;
        });
      }
    } catch (e) {
      debugPrint('Check vote error: $e');
      if (mounted) setState(() => _isCheckingVoteStatus = false);
    }
  }

  /// Silently pushes correct image URLs to Supabase for candidates with missing images.
  Future<void> _patchCandidateImages() async {
    for (final entry in _candidateImages.entries) {
      try {
        final rows = await _supabase
            .from('candidates')
            .select('id, image_url')
            .ilike('name', entry.key);
        for (final row in rows as List) {
          final existing = (row['image_url'] as String?)?.trim() ?? '';
          if (existing.isEmpty) {
            await _supabase
                .from('candidates')
                .update({'image_url': entry.value})
                .eq('id', row['id']);
          }
        }
      } catch (_) {
        // Silently ignore — fallback map in _resolveImage still covers it
      }
    }
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
    if (_hasVoted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ You have already voted for $_votedCandidateName! Only 1 vote is allowed per voter.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (!_isVotingEnabled) {
      return;
    }

    setState(() {
      _isVotingEnabled = false;
    });

    final voterKey = widget.regNo ?? widget.loggedInUser ?? _sessionId;

    try {
      // 1. Get election round start time
      final epochRes = await _supabase
          .from('candidates')
          .select('created_at')
          .eq('name', 'Joseph Vijay')
          .maybeSingle();
      final epochString = epochRes?['created_at']?.toString() ?? '1970-01-01T00:00:00Z';

      // 2. Re-check server-side to guarantee strictly 1 vote per user in this round
      final existing = await _supabase
          .from('vote_logs')
          .select('id')
          .eq('session_id', voterKey)
          .gte('voted_at', epochString);

      if (existing.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _hasVoted = true;
          _isVotingEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('⚠️ You have already cast your vote! Second vote is not permitted.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      // 1. Increment candidate vote count
      final cur = await _supabase.from('candidates').select('votes').eq('id', id).single();
      final newV = ((cur['votes'] as num?)?.toInt() ?? 0) + 1;
      await _supabase.from('candidates').update({'votes': newV}).eq('id', id);

      // 2. Insert vote log recording the voter's register number / ID
      await _supabase.from('vote_logs').insert({
        'candidate_name': name,
        'session_id': voterKey,
      });

      if (!mounted) return;
      setState(() {
        _hasVoted = true;
        _votedCandidateName = name;
        _isVotingEnabled = false;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 10),
              const Text('Vote Recorded!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thank you, ${widget.loggedInUser ?? "Voter"}!'),
              const SizedBox(height: 8),
              Text(
                'Your vote for $name has been officially registered.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '🔒 Each voter is allowed only 1 vote. Your ballot has now been closed.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
      });
    }
  }

  Future<void> _resetVotes() async {
    try {
      final newEpoch = DateTime.now().toUtc().toIso8601String();

      // 1. Reset all candidate vote counters to 0
      await _supabase.from('candidates').update({'votes': 0}).gte('votes', 0);

      // 2. Advance the election epoch timestamp on Joseph Vijay's row (marks new election start)
      await _supabase.from('candidates').update({'created_at': newEpoch}).eq('name', 'Joseph Vijay');

      // 3. Clear all rows from vote_logs
      try {
        await _supabase.from('vote_logs').delete().filter('id', 'not.is', 'null');
      } catch (e) {
        debugPrint('Vote logs delete warning (check RLS DELETE policy): $e');
      }

      if (!mounted) return;
      setState(() {
        _hasVoted = false;
        _votedCandidateName = '';
        _isVotingEnabled = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('🔄 All candidate votes and voter records have been reset!'),
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

  void _openDashboard() {
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
                Text('Admin Dashboard Login',
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
                      pc.text.trim() == 'sanjay@2007') {
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
                    ).then((_) {
                      if (mounted) {
                        _checkIfUserAlreadyVoted();
                        _loadCandidates();
                      }
                    });
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
          if (widget.loggedInUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Chip(
                avatar: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 16, color: Colors.blue),
                ),
                label: Text(
                  widget.loggedInUser!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: Colors.blue.shade900,
                side: BorderSide.none,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Ballot',
            onPressed: _loadCandidates,
            iconSize: 24,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Live Results Dashboard',
            onPressed: _openDashboard,
            iconSize: 26,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const UserLoginScreen()),
              );
            },
            iconSize: 24,
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
                    if (_isCheckingVoteStatus)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Checking Status...',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      )
                    else if (_hasVoted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Voted: $_votedCandidateName (1/1)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '✅ Ready (1 Vote Allowed)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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
                              final isThisVoted = _hasVoted && _votedCandidateName.toLowerCase() == c.name.toLowerCase();

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isThisVoted ? Colors.purple.shade300 : Colors.grey.shade200,
                                    width: isThisVoted ? 2 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  child: ListTile(
                                    leading: _CandidateAvatar(
                                      imageUrl: c.imageUrl,
                                      name: c.name,
                                      radius: 26,
                                    ),
                                    title: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isThisVoted ? Colors.purple.shade900 : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      isThisVoted ? 'Your Chosen Candidate' : 'Official Candidate',
                                      style: TextStyle(
                                        color: isThisVoted ? Colors.purple.shade600 : Colors.grey.shade500,
                                        fontSize: 12,
                                        fontWeight: isThisVoted ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    trailing: SizedBox(
                                      height: 44,
                                      width: 104,
                                      child: ElevatedButton(
                                        onPressed:
                                            (!_hasVoted && _isVotingEnabled) ? () => _castVote(c.id, c.name) : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isThisVoted
                                              ? Colors.purple.shade700
                                              : (!_hasVoted && _isVotingEnabled)
                                                  ? Colors.blue.shade700
                                                  : Colors.grey.shade400,
                                          foregroundColor: Colors.white,
                                          elevation: (!_hasVoted && _isVotingEnabled) ? 3 : 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: isThisVoted
                                            ? const Text(
                                                'VOTED',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  letterSpacing: 1.0,
                                                ),
                                              )
                                            : _hasVoted
                                                ? const Text(
                                                    'LOCKED',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      letterSpacing: 1.0,
                                                    ),
                                                  )
                                                : const Text(
                                                    'VOTE',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      letterSpacing: 1.2,
                                                    ),
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

    // 2. Continuous 1-second polling fallback so dashboard ALWAYS stays up-to-date
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
                                      leading: _CandidateAvatar(
                                        imageUrl: c.imageUrl,
                                        name: c.name,
                                        radius: 24,
                                        showWinnerBadge: isWinner,
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
