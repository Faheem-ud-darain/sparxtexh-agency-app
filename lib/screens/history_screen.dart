import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_constants.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: usersCol.doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final bool isAdmin = (userData?['role'] == 'admin') || (uid == kSuperAdminUID);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBg, kCard.withValues(alpha: 0.5)],
            ),
          ),
          child: Column(
            children: [
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () async {
                          final batch = db.batch();
                          final snap = await historyCol.get();
                          for (var d in snap.docs) {
                            batch.delete(d.reference);
                          }
                          await batch.commit();
                          if (context.mounted) showSystemNotification(context, 'ACTIVITY LOGS PURGED');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: kError.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kError.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_sweep_rounded, size: 16, color: kError),
                              const SizedBox(width: 8),
                              Text('CLEAR HISTORY', style: GoogleFonts.syncopate(fontSize: 9, fontWeight: FontWeight.w900, color: kError, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: historyCol.orderBy('timestamp', descending: true).limit(50).snapshots(),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: kAccent.withValues(alpha: 0.5)));
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: kMuted.withValues(alpha: 0.1)),
                            const SizedBox(height: 16),
                            Text('LOG_EMPTY', style: GoogleFonts.syncopate(fontSize: 12, fontWeight: FontWeight.w900, color: kMuted, letterSpacing: 2)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      itemCount: docs.length,
                      itemBuilder: (ctx, idx) {
                        final d = docs[idx].data() as Map<String, dynamic>;
                        final ts = d['timestamp'] as Timestamp?;
                        String toDateStr(Timestamp? t) => t != null ? DateFormat('dd-MM-yyyy').format(t.toDate()) : '';
                        final prevDoc = idx > 0 ? docs[idx - 1] : null;
                        final prevData = prevDoc?.data() as Map<String, dynamic>?;
                        final isFirstOfDay = idx == 0 || toDateStr(prevData?['timestamp'] as Timestamp?) != toDateStr(ts);
                        
                        final time = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '--:--';
                        final date = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : '';
                        final type = d['type'] as String? ?? 'LOG';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            if (isFirstOfDay) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 24, bottom: 20),
                                child: Row(
                                  children: [
                                    Text(date.toUpperCase(), style: GoogleFonts.syncopate(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: kAccent)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Divider(color: kAccent.withValues(alpha: 0.1), thickness: 0.5)),
                                  ],
                                ),
                              ),
                            ],
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      Container(width: 2, height: 12, color: idx == 0 && isFirstOfDay ? Colors.transparent : kAccent.withValues(alpha: 0.2)),
                                      _timelineIcon(type),
                                      Expanded(child: Container(width: 2, color: idx == docs.length - 1 ? Colors.transparent : kAccent.withValues(alpha: 0.2))),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      child: Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: kCard.withValues(alpha: 0.1), 
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: kBorder.withValues(alpha: 0.05)),
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(children: [
                                            Container(width: 4, color: _logColor(type)),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(20),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(_logLabel(type).toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: _logColor(type), letterSpacing: 1.5)),
                                                        Text(time, style: GoogleFonts.inter(fontSize: 10, color: kMuted.withValues(alpha: 0.5), fontWeight: FontWeight.w800)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      (d['description'] ?? '').toUpperCase(), 
                                                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: kText, letterSpacing: -0.2, height: 1.5)
                                                    ),
                                                    if (d['amount'] != null) ...[
                                                      const SizedBox(height: 16),
                                                      Text(
                                                        formatPKR((d['amount'] as num).toDouble()), 
                                                        style: GoogleFonts.syncopate(color: (d['amount'] as num) < 0 ? kError : kSuccess, fontWeight: FontWeight.w900, fontSize: 13)
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: (idx * 50).ms, duration: 400.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timelineIcon(String type) {
    IconData icon = Icons.data_usage_rounded;
    Color color = kAccent;
    switch(type) {
      case 'ATTENDANCE': icon = Icons.fingerprint_rounded; color = kSuccess; break;
      case 'TASK_SUBMITTED': icon = Icons.file_present_rounded; color = kAccent; break;
      case 'TASK_VERIFIED': icon = Icons.verified_rounded; color = kSuccess; break;
      case 'EXPENSE_ADDED': icon = Icons.remove_circle_outline_rounded; color = kError; break;
      case 'CLIENT_ADDED': icon = Icons.group_add_rounded; color = kAccent; break;
      case 'REVENUE_ADDED': icon = Icons.add_circle_outline_rounded; color = kSuccess; break;
      case 'PAYMENT_ADDED': icon = Icons.payments_rounded; color = kGold; break;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 0),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Color _logColor(String type) {
    switch(type) {
      case 'ATTENDANCE':    return kSuccess;
      case 'TASK_SUBMITTED': return kAccent;
      case 'TASK_VERIFIED':  return kSuccess;
      case 'EXPENSE_ADDED':  return kError;
      case 'REVENUE_ADDED':  return kSuccess;
      case 'PAYMENT_ADDED':  return kGold;
      default: return kAccent;
    }
  }

  String _logLabel(String type) {
    return type.replaceAll('_', ' ');
  }
}
