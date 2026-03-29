import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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

        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('My Workspace', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          // ── Stats Row ──
          Row(children: [
            _statChip('${docs.length}', 'Total', Colors.white30),
            const SizedBox(width: 8),
            _statChip('${assigned.length}', 'Active', kMuted),
            const SizedBox(width: 8),
            _statChip('${pending.length}', 'Pending', Colors.orangeAccent),
            const SizedBox(width: 8),
            _statChip('${verified.length}', 'Verified', Colors.greenAccent),
          ]),
          const SizedBox(height: 20),

          if (snap.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (docs.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(60),
              child: Column(children: [
                Icon(Icons.assignment_turned_in_outlined, size: 64, color: kMuted.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text('No tasks assigned yet.', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
              ])))
          else ...[
            if (assigned.isNotEmpty) ...[_sectionHeader('Active Tasks', assigned.length), ...assigned.map((d) => _TaskCard(doc: d))],
            if (pending.isNotEmpty)  ...[_sectionHeader('Reviews', pending.length), ...pending.map((d) => _TaskCard(doc: d))],
            if (verified.isNotEmpty) ...[_sectionHeader('Completed', verified.length), ...verified.map((d) => _TaskCard(doc: d))],
          ],
        ]);
      },
    );
  }

  Widget _sectionHeader(String label, int count) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(children: [
      Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: kMuted, letterSpacing: 1.2)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
      ),
    ]),
  );

  Widget _statChip(String count, String label, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder),
    ),
    child: Column(children: [
      Text(count, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  ));
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
    final isOverdue   = timeLeft == 'OVERDUE';
    final isUrgent    = d['is_urgent'] == true;
    final isInternal  = d['is_internal'] == true;
    final service     = d['service'] as String? ?? '';
    final pts         = (serviceWeights[service] ?? 0) + (isUrgent ? urgentBonus : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isUrgent ? Colors.orangeAccent.withOpacity(0.3) : kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(d['title'] ?? 'Untitled', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white))),
            statusBadge(status),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!isInternal) _chip(Icons.business_rounded, d['client_name'] as String? ?? '-'),
            _chip(Icons.auto_awesome_mosaic_rounded, service.replaceAll('_', ' ')),
            _chip(Icons.stars_rounded, '$pts pts', color: kMuted),
            if (isUrgent) _chip(Icons.bolt, 'URGENT', color: Colors.orangeAccent),
          ]),
          if (timeLeft.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isOverdue ? Colors.redAccent : Colors.greenAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isOverdue ? Icons.priority_high : Icons.timer_outlined, size: 14, color: isOverdue ? Colors.redAccent : Colors.greenAccent),
                const SizedBox(width: 4),
                Text(timeLeft, style: GoogleFonts.inter(color: isOverdue ? Colors.redAccent : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          if (status == 'ASSIGNED') ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kAccent, padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (await isMonthLocked()) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Month is locked'))); return; }
                await tasksCol.doc(doc.id).update({'status': 'PENDING_VERIFICATION', 'submitted_at': FieldValue.serverTimestamp()});
                await logEvent(type: 'TASK_SUBMITTED', description: '"${d['title']}" submitted', taskId: doc.id, clientId: d['client_id'] as String?);
              },
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.send_rounded, size: 16),
                const SizedBox(width: 8),
                Text('Submit for Verification', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
            )),
          ],
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color color = Colors.white54}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.1))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}
