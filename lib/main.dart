// SparxTexh Agency Hub - V1.0
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_constants.dart';
import 'screens/pl_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await refreshServiceWeights();
  runApp(const AgencyOpsApp());
}

class AgencyOpsApp extends StatelessWidget {
  const AgencyOpsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agency Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: kBg,
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
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snap.hasData) return const LoginScreen();
        return const MainDashboard();
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [kBg, kCard], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.hub_rounded, size: 80, color: kAccent.withValues(alpha: 0.8)),
          const SizedBox(height: 24),
          Text('SparxTexh\nAgency Hub', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
          const SizedBox(height: 12),
          Text('Meritocratic Profit-Share Platform', style: GoogleFonts.inter(color: Colors.white30, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kAccent, padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10, shadowColor: kAccent.withValues(alpha: 0.4),
              ),
              onPressed: () async {
                try {
                  final cred = await FirebaseAuth.instance.signInAnonymously();
                  await usersCol.doc(cred.user!.uid).set({
                    'uid': cred.user!.uid, 'role': 'member', 'points': 0, 'name': 'New Member ${cred.user!.uid.substring(0, 4)}',
                  }, SetOptions(merge: true));
                } catch (e) { debugPrint('Login Error: $e'); }
              },
              child: const Text('Enter Workspace', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            )),
          ),
        ]),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  void _checkName(String currentName, String uid) {
    if (currentName.startsWith('New Member')) {
      final ctrl = TextEditingController();
      Future.delayed(const Duration(seconds: 1), () => showDialog(
        context: context, barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Welcome!', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Please set your real name for the leaderboard.', style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 20),
            TextField(controller: ctrl, decoration: kInputDecoration('Your Full Name', Icons.person)),
          ]),
          actions: [
            TextButton(onPressed: () async {
               if (ctrl.text.trim().isNotEmpty) {
                 await usersCol.doc(uid).update({'name': ctrl.text.trim()});
                 Navigator.pop(ctx);
               }
            }, child: const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<DocumentSnapshot>(
      stream: usersCol.doc(uid).snapshots(),
      builder: (_, userSnap) {
        final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final isAdmin = (data['role'] as String? ?? 'member') == 'admin';
        final points = (data['points'] as num? ?? 0).toInt();
        final name = data['name'] as String? ?? '';
        
        _checkName(name, uid);

        final screens = [const FinancialOverviewScreen(), const TaskWorkspaceScreen(), if (isAdmin) const AdminVerificationScreen(), const AttendanceScreen(), const HistoryScreen()];
        final dests = [
          const NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'P&L'),
          const NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Tasks'),
          if (isAdmin) const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          const NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), selectedIcon: Icon(Icons.qr_code_scanner_rounded), label: 'Team'),
          const NavigationDestination(icon: Icon(Icons.history_edu_rounded), selectedIcon: Icon(Icons.history_edu_rounded), label: 'Ledger'),
        ];

        return StreamBuilder<DocumentSnapshot>(
          stream: appConfigDoc.snapshots(),
          builder: (_, cfgSnap) {
            final cfg = cfgSnap.data?.data() as Map<String, dynamic>? ?? {};
            final locked = cfg['month_locked'] == true;

            return Scaffold(
              appBar: AppBar(
                backgroundColor: kBg, surfaceTintColor: Colors.transparent,
                title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Agency Hub', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
                    if (locked) ...[
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                        child: const Text('LOCKED', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900))),
                    ],
                  ]),
                  Text(isAdmin ? 'Founders View' : 'Team Member', style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ]),
                actions: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100), border: Border.all(color: kAccent.withValues(alpha: 0.2))),
                    child: Center(child: Row(children: [
                      const Icon(Icons.stars_rounded, color: kAccent, size: 16),
                      const SizedBox(width: 6),
                      Text('$points PTS', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: kAccent)),
                    ])),
                  ),
                  if (isAdmin) IconButton(icon: const Icon(Icons.settings_suggest_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()))),
                  IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white38, size: 20)),
                ],
              ),
              body: screens[_currentIndex.clamp(0, screens.length - 1)],
              bottomNavigationBar: NavigationBar(
                height: 65,
                indicatorColor: kAccent.withValues(alpha: 0.15),
                backgroundColor: kCard,
                elevation: 10,
                selectedIndex: _currentIndex.clamp(0, dests.length - 1),
                onDestinationSelected: (i) => setState(() => _currentIndex = i),
                destinations: dests,
              ),
            );
          },
        );
      },
    );
  }
}
