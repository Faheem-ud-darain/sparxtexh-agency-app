import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_constants.dart';
import '../main.dart'; // To access AIService

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});
  @override State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  bool _isGenerating = false;

  Future<void> _generateReport() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // Basic check for authenticated user

    setState(() => _isGenerating = true);
    try {
      final curMonth = DateFormat('yyyy-MM').format(DateTime.now());
      
      // 1. Fetch Automated Revenue (Payments from this month)
      final paySnap = await paymentsCol.where('month', isEqualTo: curMonth).get();
      double totalRev = 0.0;
      for (var doc in paySnap.docs) {
        totalRev += (doc.data()['amount'] as num? ?? 0).toDouble();
      }

      // 2. Fetch Expenses (Monthly Team Spending)
      final expSnap = await expensesCol.where('month', isEqualTo: curMonth).get();
      double totalExp = 0.0;
      for (var doc in expSnap.docs) {
        totalExp += (doc.data()['amount'] as num? ?? 0).toDouble();
      }

      // 3. Fetch Task Metrics
      final taskSnap = await tasksCol.get();
      final allTasks = taskSnap.docs;
      final pendingCount = allTasks.where((d) => ['ASSIGNED', 'PENDING_VERIFICATION'].contains(d.data()['status'])).length;
      
      final completedToday = allTasks.where((d) {
        final data = d.data();
        if (data['status'] != 'VERIFIED') return false;
        return true; 
      }).length;

      final totalVerified = allTasks.where((d) => d.data()['status'] == 'VERIFIED').length;
      final completionRate = allTasks.isEmpty ? 0.0 : (totalVerified / allTasks.length) * 100;

      // 4. Call Groq AIService
      final report = await AIService.generateDailyInsight(
        revenue: totalRev,
        expenses: totalExp,
        pendingTasks: pendingCount,
        completedTasks: completedToday,
        completionRate: completionRate,
      );
      
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await db.collection('reports').doc('daily_insight').set({
        'last_updated': todayDate,
        'report_markdown': report,
        'revenue_snapshot': totalRev,
        'expense_snapshot': totalExp,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        showSystemNotification(context, 'GROQ STRATEGY SYNC COMPLETE');
      }
    } catch (e) {
      if (mounted) {
        showSystemNotification(context, 'SYNC ERROR: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isSuperAdmin = uid == kSuperAdminUID;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('reports').doc('daily_insight').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final markdown = data['report_markdown'] as String? ?? '# Strategy Pending\n\nClick the Sync icon to generate the mockup strategy report.';
        final lastUpdated = data['last_updated'] as String? ?? 'Never';
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        // Auto-trigger if not updated today
        if (lastUpdated != today && !_isGenerating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _generateReport();
          });
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: kAccent, size: 28),
                        const SizedBox(width: 12),
                        Text('AI STRATEGY', style: GoogleFonts.syncopate(color: kText, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      ],
                    ),
                    if (isSuperAdmin)
                      _isGenerating 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: kGold))
                        : IconButton(
                            icon: const Icon(Icons.sync_rounded, color: kGold, size: 28), 
                            onPressed: _generateReport,
                            tooltip: 'Sync Strategy',
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Last Strategic Update: $lastUpdated'.toUpperCase(), style: GoogleFonts.inter(color: kMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 32),
                Expanded(
                  child: PulseGlow(
                    color: _isGenerating ? kAccent : Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: kBentoDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isGenerating) ...[
                            LinearProgressIndicator(backgroundColor: kBorder, color: kAccent, minHeight: 1, borderRadius: BorderRadius.circular(10)),
                            const SizedBox(height: 16),
                            Text('Consulting Strategy Engine...', style: GoogleFonts.inter(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 24),
                          ],
                          Expanded(
                            child: Markdown(
                              data: markdown,
                              styleSheet: MarkdownStyleSheet(
                                p: GoogleFonts.inter(color: kText, fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
                                h1: GoogleFonts.syncopate(color: kAccent, fontSize: 20, fontWeight: FontWeight.w900, height: 2),
                                h2: GoogleFonts.inter(color: kGold, fontSize: 18, fontWeight: FontWeight.w900, height: 1.8),
                                h3: GoogleFonts.inter(color: kText, fontSize: 16, fontWeight: FontWeight.w900, height: 1.6),
                                listBullet: const TextStyle(color: kAccent),
                                code: const TextStyle(backgroundColor: Colors.white10, color: kAccent),
                                codeblockDecoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 800.ms).scale(begin: const Offset(0.98, 0.98), curve: Curves.easeOutCubic),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }
}
