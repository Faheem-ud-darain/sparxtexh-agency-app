import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app_constants.dart';

class TaskWorkspaceScreen extends StatelessWidget {
  const TaskWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: tasksCol.where('assigned_to', isEqualTo: uid).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final assigned  = docs.where((d) => (d.data() as Map)['status'] == 'ASSIGNED').toList();
        final pending   = docs.where((d) => (d.data() as Map)['status'] == 'PENDING_VERIFICATION').toList();
        final verified  = docs.where((d) => (d.data() as Map)['status'] == 'VERIFIED').toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TACTICAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: kAccent, letterSpacing: 2)),
                  Text('WORKSPACE', style: GoogleFonts.syncopate(fontSize: 20, fontWeight: FontWeight.w900, color: kText, letterSpacing: -1)),
                ])),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: kGlowDecoration(color: kAccent.withValues(alpha: 0.1), borderRadius: 16),
                  child: const Icon(Icons.hub_rounded, color: kAccent, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // ── Stats Dashboard (Bento Grid) ──
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _statChip('${docs.length}', 'TOTAL', kText).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                _statChip('${assigned.length}', 'ACTIVE', kAccent).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                _statChip('${pending.length}', 'REVIEW', kGold).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                _statChip('${verified.length}', 'DONE', kSuccess).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              ],
            ),
            const SizedBox(height: 48),

            if (snap.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: kAccent)))
            else if (docs.isEmpty)
              SizedBox(
                height: 300,
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.auto_awesome_rounded, size: 48, color: kMuted),
                  const SizedBox(height: 16),
                  Text('OPERATIONAL SILENCE.', style: GoogleFonts.inter(color: kMuted, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ])),
              )
            else ...[
              if (assigned.isNotEmpty) ...[_sectionLabel('FIELD OPERATIONS'), ...assigned.map((d) => _TaskCard(doc: d))],
              if (pending.isNotEmpty)  ...[_sectionLabel('INTELLIGENCE REVIEW'), ...pending.map((d) => _TaskCard(doc: d))],
              if (verified.isNotEmpty) ...[_sectionLabel('ARCHIVED SUCCESS'), ...verified.map((d) => _TaskCard(doc: d))],
            ],
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 20),
    child: Row(children: [
      Text(label, style: GoogleFonts.syncopate(fontSize: 10, fontWeight: FontWeight.w900, color: kMuted, letterSpacing: 1.5)),
      const SizedBox(width: 16),
      Expanded(child: Divider(color: kText.withValues(alpha: 0.05), thickness: 1)),
    ]),
  );

  Widget _statChip(String value, String label, Color color) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: kCard.withValues(alpha: 0.15), 
      borderRadius: BorderRadius.circular(20), 
      border: Border.all(color: color.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10, spreadRadius: 1),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(value, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 32, height: 1)),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(color: kMuted.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ]
    ),
  );
}

class _TaskCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _TaskCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d      = doc.data() as Map<String, dynamic>;
    final status = d['status'] as String? ?? 'ASSIGNED';
    final deadline    = computeDeadline(d);
    final timeLeft    = formatTimeRemaining(deadline);
    final isOverdue   = timeLeft == 'OVERDUE' && status != 'VERIFIED';
    final isUrgent    = d['is_urgent'] == true;
    final isInternal  = d['is_internal'] == true;
    final service     = d['service'] as String? ?? '';
    final pts         = (serviceWeights[service] ?? 0) + (isUrgent ? urgentBonus : 0);

    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, top: 8, left: 8, right: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['title'] ?? 'MISSION_UNTITLED', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: kText, height: 1.2)),
                const SizedBox(height: 8),
                Text(isInternal ? 'INTERNAL CORE' : (d['client_name'] as String? ?? 'UNKNOWN PARTNER').toUpperCase(), 
                  style: GoogleFonts.inter(color: kAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ])),
              statusBadge(status),
            ],
          ),
          const SizedBox(height: 24),
          
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(Icons.auto_awesome_mosaic_rounded, service.replaceAll('_', ' ').toUpperCase()),
            _chip(Icons.bolt_rounded, '$pts POINTS', color: isUrgent ? kGold : kAccent),
            if (isUrgent) _chip(Icons.warning_amber_rounded, 'HIGH PRIORITY', color: kGold),
          ]),
          
          if (timeLeft.isNotEmpty && status != 'VERIFIED') ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (isOverdue ? kError : kSuccess).withValues(alpha: 0.1)),
              ),
              child: Row(children: [
                Icon(isOverdue ? Icons.priority_high_rounded : Icons.timer_outlined, size: 16, color: isOverdue ? kError : kSuccess),
                const SizedBox(width: 12),
                Text(timeLeft, style: GoogleFonts.syncopate(color: isOverdue ? kError : kSuccess, fontSize: 11, fontWeight: FontWeight.w900)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: kMuted, size: 16),
              ]),
            ),
          ],
          
          if (status == 'ASSIGNED') ...[
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, child: kPrimaryButton(
              label: 'SUBMIT VERIFICATION',
              icon: Icons.unarchive_rounded,
              onPressed: () async {
                if (await isMonthLocked()) {
                  if (context.mounted) showSystemNotification(context, 'SECURITY LOCK: Month is deactivated.', isError: true);
                  return;
                }
                await tasksCol.doc(doc.id).update({'status': 'PENDING_VERIFICATION', 'submitted_at': FieldValue.serverTimestamp()});
                await logEvent(type: 'TASK_SUBMITTED', description: 'Task "${d['title']}" submitted for verification', taskId: doc.id, clientId: d['client_id'] as String?);
                if (context.mounted) {
                  showSystemNotification(context, 'MISSION VERIFICATION SUBMITTED', isError: false);
                }
              },
            )),
          ],
        ]),
      ),
    );

    final bool shouldGlow = isUrgent && status != 'VERIFIED';

    return (shouldGlow ? PulseGlow(color: kGold, child: cardContent) : cardContent)
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.05, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _chip(IconData icon, String label, {Color color = kMuted}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05), 
      borderRadius: BorderRadius.circular(12), 
      border: Border.all(color: color.withValues(alpha: 0.1)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    ]),
  );

  DateTime? computeDeadline(Map d) {
    final ts = d['created_at'] as Timestamp?;
    if (ts == null) return null;
    return ts.toDate().add(const Duration(hours: 24));
  }

  String formatTimeRemaining(DateTime? deadline) {
    if (deadline == null) return '';
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'OVERDUE';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}H ${mins}M REMAINING';
  }

  Widget statusBadge(String status) {
    final color = status == 'VERIFIED' ? kSuccess : status == 'PENDING_VERIFICATION' ? kGold : kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(status.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }
}
