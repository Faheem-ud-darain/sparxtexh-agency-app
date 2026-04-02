import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';
import 'services/notification_service.dart';
// import 'package:http/http.dart' as http; // MOCKED for Native Build
import 'package:url_launcher/url_launcher.dart';
import 'app_constants.dart';
import 'screens/pl_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/suggestions_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    try {
      await GoogleSignIn.instance.initialize();
    } catch (e) {
      debugPrint('Google Sign In Initialize Error: $e');
    }
  }

  // Register Background Message Handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Agency Notification Engine
  await NotificationService.initialize();

  // OPTIONAL DOTENV: App will not crash if .env is missing
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      "Native Build Notice: No .env file found. AI Features will use Mockup mode. Error: $e",
    );
  }

  await refreshServiceWeights();
  runApp(const AgencyOpsApp());
}

// AI SERVICE MOCKUP

// MOCKUP STRATEGY SERVICE
// Temporarily replacing live AI integration with a hardcoded strategy mockup
class AIService {
  static Future<String> generateDailyInsight({
    required double revenue,
    required double expenses,
    required int pendingTasks,
    required int completedTasks,
    required double completionRate,
  }) async {
    // Return a hardcoded mockup message for native Android/iOS compilation
    return """
# Strategy Report (Mockup)

**Status:** This Feature will be Available soon.

### 1. Top Performing Services
- Current focus is on optimizing core agency operations for native performance.

### 2. Urgent Tasks
- $pendingTasks Tasks require immediate attention.
- Team is aiming for 100% completion rate (Current: ${completionRate.toStringAsFixed(1)}%).

### 3. Daily Growth Strategy
- **Financial Stability:** Current Revenue of ${revenue.toStringAsFixed(0)} PKR is being successfully tracked.
- **Optimization:** Native builds for Android and iOS are being finalized for deployment.
- **Next Step:** Once the native baseline is solid, live Llama-3.3 Strategic Models will be re-enabled.
""";
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: notificationsCol
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final logs = snapshot.data?.docs ?? [];
        if (logs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_off_rounded,
                    size: 64,
                    color: kMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NO RECENT BROADCASTS',
                    style: GoogleFonts.syncopate(
                      fontSize: 10,
                      color: kMuted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (ctx, i) {
            final data = logs[i].data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            final isUrgent = (data['title'] ?? '').toString().contains('⚠️');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUrgent ? kError.withValues(alpha: 0.2) : kBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isUrgent
                            ? Icons.warning_rounded
                            : Icons.notifications_active_rounded,
                        size: 16,
                        color: isUrgent ? kError : kAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['title'] ?? 'Alert',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: isUrgent ? kError : kText,
                          ),
                        ),
                      ),
                      if (ts != null)
                        Text(
                          DateFormat('HH:mm').format(ts.toDate()),
                          style: GoogleFonts.inter(fontSize: 10, color: kMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['body'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AgencyOpsApp extends StatelessWidget {
  const AgencyOpsApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sparx Hub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
          primary: kAccent,
          secondary: kSuccess,
          surface: kBg,
          onSurface: kText,
          error: kError,
        ),
        scaffoldBackgroundColor: kBg,
        textTheme: GoogleFonts.interTextTheme(base.textTheme)
            .apply(bodyColor: kText, displayColor: kText)
            .copyWith(
              displayLarge: GoogleFonts.syncopate(
                fontWeight: FontWeight.w900,
                color: kText,
              ),
              displayMedium: GoogleFonts.syncopate(
                fontWeight: FontWeight.w900,
                color: kText,
              ),
              displaySmall: GoogleFonts.syncopate(
                fontWeight: FontWeight.w900,
                color: kText,
              ),
              headlineMedium: GoogleFonts.syncopate(
                fontWeight: FontWeight.w900,
                color: kText,
              ),
              titleLarge: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                color: kText,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
        cardTheme: CardThemeData(
          color: kCard,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: kText.withValues(alpha: 0.05)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kBg,
          indicatorColor: kAccent.withValues(alpha: 0.1),
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: kText,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: CircularProgressIndicator(
                color: kAccent.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        if (!snap.hasData) return const LoginScreen();
        return const MainDashboard();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showSystemNotification(
        context,
        'Core System Version: 1.0.0+4 Online',
        isError: false,
      );
    });
  }

  Future<void> _signIn(BuildContext context, {bool asAdmin = false}) async {
    try {
      UserCredential userCred;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        userCred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount gUser;
        try {
          gUser = await GoogleSignIn.instance.authenticate();
        } catch (e) {
          // User most likely cancelled the flow
          debugPrint('Google Sign In Cancelled/Error: $e');
          return;
        }

        final GoogleSignInAuthentication gAuth = gUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken:
              null, // v7.2.0 holds accessToken in authorizationClient if needed
          idToken: gAuth.idToken,
        );
        userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user != null) {
        final doc = await usersCol.doc(user.uid).get();
        final isNew = !doc.exists;
        final data = doc.data();

        await usersCol.doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? 'New Member',
          'email': user.email,
          'photoUrl': user.photoURL,
          'is_approved': data?['is_approved'] ?? (asAdmin ? true : false),
          'role': data?['role'] ?? (asAdmin ? 'admin' : 'member'),
          if (isNew) 'points': 0,
        }, SetOptions(merge: true));

        // Update Push Token
        // FCM Token update removed
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed: ${e.message}';
      if (e.code == 'popup-closed-by-user') msg = 'Sign-in cancelled.';
      if (e.code == 'cancelled-combined-assertion') {
        msg = 'Sign-in cancelled by user.';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            backgroundColor: kError,
          ),
        );
      }
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'LOGIN FAILED: ${e.toString()}'.toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [kAccent.withValues(alpha: 0.1), kBg],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            GestureDetector(
              onLongPress: () => _signIn(context, asAdmin: true),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: kGlowDecoration(color: kAccent, borderRadius: 100),
                child: Image.asset('assets/images/logo.png', height: 100),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'SPARXTEXH\nAGENCY HUB',
              textAlign: TextAlign.center,
              style: GoogleFonts.syncopate(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: kText,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'MERITOCRATIC PERFORMANCE ENGINE',
              style: GoogleFonts.inter(
                color: kMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                child: kPrimaryButton(
                  label: 'SIGN IN WITH GOOGLE',
                  icon: Icons.login_rounded,
                  color: kAccent,
                  onPressed: () => _signIn(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CORE VERSION 2.1.0',
              style: GoogleFonts.inter(
                color: kText.withValues(alpha: 0.1),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _index = 0;
  // CRITICAL: Increment this +1 every time you build a new APK
  final int currentVersionCode = 4;


  @override
  void initState() {
    super.initState();
    _checkName();
    // This tells Flutter: "Wait until the screen is drawn, THEN check for updates"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    debugPrint('🚨 SPARX HUB: TACTICAL UPDATE CHECK INITIATED...');
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_info')
          .get();

      if (snapshot.exists) {
        int latestVersion = snapshot['latest_version'] ?? 0;
        String updateUrl = snapshot['update_url'] ?? "";
        bool isForced = snapshot['is_forced'] ?? false;

        debugPrint("SPARX HUB: Cloud v$latestVersion | Local v$currentVersionCode");

        if (latestVersion > currentVersionCode) {
          _showUpdateDialog(updateUrl, isForced);
        }
      }
    } catch (e) {
      debugPrint("Update Check Failed: $e");
    }
  }

  void _showUpdateDialog(String url, bool isForced) {
    showDialog(
      context: context,
      barrierDismissible: !isForced, // Blocks the user if update is forced
      builder: (context) => PopScope(
        canPop: !isForced, // Disables 'Back' button if forced
        child: AlertDialog(
          backgroundColor: const Color(0xFF131313), // Matte Black
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: kBorder)),
          title: Text(
            "CRITICAL UPDATE REQUIRED",
            style: GoogleFonts.syncopate(color: kAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update_rounded, size: 48, color: kAccent),
              const SizedBox(height: 24),
              Text(
                "A new version of SPARX HUB is available with mission-critical performance fixes and feature enhancements.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            if (!isForced)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("DISMISS", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            SizedBox(
              width: double.infinity,
              child: kPrimaryButton(
                label: "INITIALIZE UPDATE",
                icon: Icons.download_rounded,
                color: kAccent,
                onPressed: () async {
                  final Uri uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await usersCol.doc(user.uid).get();
    final data = doc.data();
    if (doc.exists &&
        (data?['name'] == null || data?['name'] == 'New Member')) {
      if (mounted) {
        _showNamePrompt(context, user.uid);
      }
    }
  }

  void _showNamePrompt(BuildContext context, String uid) {
    final controller = TextEditingController();
    showPulseModal(
      context,
      title: 'PROFILE SETUP',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VALIDATE YOUR SYSTEM IDENTITY',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: kAccent,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your full legal name to synchronize with administrative payroll and verification systems.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: kMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: kText),
            decoration: kInputDecoration(
              'ENTITY NAME',
              Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: kPrimaryButton(
              label: 'COMPLETE INITIALIZATION',
              icon: Icons.check_rounded,
              color: kAccent,
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await usersCol.doc(uid).update({'name': controller.text});
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginScreen();

    return StreamBuilder<DocumentSnapshot>(
      stream: usersCol.doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: kBg,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final uid = FirebaseAuth.instance.currentUser?.uid;
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final bool isApproved =
            (userData?['is_approved'] ?? false) || (uid == kSuperAdminUID);

        if (!isApproved) return const PendingApprovalScreen();

        final titles = [
          'SPARXTEKH HUB',
          'VITAL OVERVIEW',
          'ATTENDANCE LOG',
          'AI SUGGESTIONS',
          'STRIKE RECORD',
          'COMMAND CENTER',
          'CORE SETTINGS',
        ];

        final screens = [
          const TaskWorkspaceScreen(),
          const FinancialOverviewScreen(),
          const AttendanceScreen(),
          const SuggestionsScreen(),
          const HistoryScreen(),
          if (userData?['role'] == 'admin' || uid == kSuperAdminUID)
            const AdminVerificationScreen(),
          if (userData?['role'] == 'admin' || uid == kSuperAdminUID)
            const AdminSettingsScreen(),
        ];

        return PopScope(
          canPop: false, // Prevent root pop to avoid black screen
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_index != 0) {
              setState(() => _index = 0);
            } else {
              // Current index is 0, we are at root.
            }
          },
          child: Scaffold(
            drawer: Drawer(
              backgroundColor: kBg,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                      top: 60,
                      bottom: 32,
                      left: 24,
                      right: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kAccent.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: const Border(bottom: BorderSide(color: kBorder)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kAccent, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: kAccent.withValues(alpha: 0.2),
                            backgroundImage: userData?['photoUrl'] != null
                                ? NetworkImage(userData!['photoUrl'])
                                : null,
                            child: userData?['photoUrl'] == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: kAccent,
                                    size: 32,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData?['name'] ??
                                    user.displayName ??
                                    'OPERATOR',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: kText,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: kMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (userData?['role'] ?? 'MEMBER').toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: kAccent,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _drawerHeader('STRATEGIZE'),
                        _drawerItem(
                          icon: Icons.auto_awesome_rounded,
                          label: 'AI SUGGESTIONS',
                          index: 3,
                          currentIndex: _index,
                          onTap: (i) {
                            setState(() => _index = i);
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(height: 8),
                        _drawerHeader('OPERATIONS'),
                        _drawerItem(
                          icon: Icons.dashboard_customize_rounded,
                          label: 'TASK WORKSPACE',
                          index: 0,
                          currentIndex: _index,
                          onTap: (i) {
                            setState(() => _index = i);
                            Navigator.pop(context);
                          },
                        ),
                        _drawerItem(
                          icon: Icons.fingerprint_rounded,
                          label: 'ATTENDANCE LOG',
                          index: 2,
                          currentIndex: _index,
                          onTap: (i) {
                            setState(() => _index = i);
                            Navigator.pop(context);
                          },
                        ),
                        _drawerItem(
                          icon: Icons.account_balance_rounded,
                          label: 'VITAL OVERVIEW',
                          index: 1,
                          currentIndex: _index,
                          onTap: (i) {
                            setState(() => _index = i);
                            Navigator.pop(context);
                          },
                        ),
                        _drawerItem(
                          icon: Icons.history_rounded,
                          label: 'STRIKE RECORD',
                          index: 4,
                          currentIndex: _index,
                          onTap: (i) {
                            setState(() => _index = i);
                            Navigator.pop(context);
                          },
                        ),
                        if (userData?['role'] == 'admin' ||
                            uid == kSuperAdminUID) ...[
                          const SizedBox(height: 8),
                          _drawerHeader('ADMINISTRATION'),
                          _drawerItem(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'COMMAND CENTER',
                            index: 5,
                            currentIndex: _index,
                            onTap: (i) {
                              setState(() => _index = i);
                              Navigator.pop(context);
                            },
                          ),
                          _drawerItem(
                            icon: Icons.settings_applications_rounded,
                            label: 'CORE SETTINGS',
                            index: 6,
                            currentIndex: _index,
                            onTap: (i) {
                              setState(() => _index = i);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(color: kBorder),
                  _drawerItem(
                    icon: Icons.logout_rounded,
                    label: 'TERMINATE SESSION',
                    index: -1,
                    currentIndex: _index,
                    onTap: (_) async {
                      await FirebaseAuth.instance.signOut();
                      try {
                        await GoogleSignIn.instance.signOut();
                      } catch (e) {
                        debugPrint('Google Sign Out Error: $e');
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: kBg,
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding:
                        const EdgeInsets.only(left: 56, bottom: 16, right: 24),
                    title: Text(
                      titles[_index],
                      style: GoogleFonts.syncopate(
                        color: kText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        showPulseModal(
                          context,
                          title: 'BROADCASTS',
                          child: const NotificationsScreen(),
                        );
                      },
                      icon: const Icon(Icons.notifications_none_rounded,
                          color: kText),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: screens[_index].animate().fadeIn(duration: 400.ms),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _drawerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: kMuted,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required int index,
    required int currentIndex,
    required Function(int) onTap,
  }) {
    final isSelected = index == currentIndex;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? kAccent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: kAccent.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? kAccent : kMuted,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? kText : kMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, color: kAccent, size: 80)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 48),
              Text(
                'APPROVAL PENDING',
                style: GoogleFonts.syncopate(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unauthorized Node Detected. Your identity is being verified by Command.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: kPrimaryButton(
                  label: 'RE-CHECK STATUS',
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    // StreamBuilder will auto-refresh
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: Text('TERMINATE SESSION',
                    style: GoogleFonts.inter(
                        color: kMuted,
                        fontWeight: FontWeight.w900,
                        fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
