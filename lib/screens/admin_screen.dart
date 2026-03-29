import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_constants.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});
  @override State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  final _titleCtrl    = TextEditingController();
  final _timeCtrl     = TextEditingController();
  final _assignCtrl   = TextEditingController();
  String? _clientId, _clientName, _service;
  bool _isUrgent = false, _isInternal = false, _saving = false;

  @override
  void dispose() { _titleCtrl.dispose(); _timeCtrl.dispose(); _assignCtrl.dispose(); super.dispose(); }

  // ─── Create Task Modal ──────────────────────────────────────────────────────
  void _showCreateTask(BuildContext ctx, List<QueryDocumentSnapshot> clients) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (bCtx, setM) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(bCtx).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Create Task', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Internal toggle
          SwitchListTile(
            tileColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kBorder)),
            title: const Text('Internal Operations Task'), subtitle: const Text('Not linked to a client', style: TextStyle(fontSize: 12)),
            value: _isInternal, activeThumbColor: Colors.tealAccent,
            onChanged: (v) => setM(() { _isInternal = v; if (v) { _clientId = null; _clientName = null; } }),
          ),
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Task Title', Icons.title)),
          const SizedBox(height: 12),
          // Client selector (only if not internal)
          if (!_isInternal) ...[
            DropdownButtonFormField<String>(
              initialValue: _clientId,
              items: clients.map((d) => DropdownMenuItem(value: d.id, child: Text((d.data() as Map)['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) { setM(() { _clientId = v; _clientName = (clients.firstWhere((d) => d.id == v).data() as Map)['name'] as String?; }); },
              dropdownColor: kCard, style: const TextStyle(color: Colors.white),
              decoration: kInputDecoration('Select Client', Icons.business),
            ),
            const SizedBox(height: 12),
          ],
          // Service selector
          DropdownButtonFormField<String>(
            initialValue: _service,
            items: serviceWeights.keys.map((s) => DropdownMenuItem(value: s, child: Text('${s.replaceAll('_', ' ')} (${serviceWeights[s]} pts)', style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
            onChanged: (v) => setM(() => _service = v),
            dropdownColor: kCard, style: const TextStyle(color: Colors.white),
            decoration: kInputDecoration('Select Service', Icons.design_services),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          // User assignment selector
          StreamBuilder<QuerySnapshot>(
            stream: usersCol.snapshots(),
            builder: (context, snapshot) {
              final users = snapshot.data?.docs ?? [];
              return DropdownButtonFormField<String>(
                value: _assignCtrl.text.isEmpty ? null : _assignCtrl.text,
                items: users.map((u) {
                  final data = u.data() as Map<String, dynamic>;
                  return DropdownMenuItem(
                    value: u.id,
                    child: Text(data['name'] ?? u.id, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) => setM(() => _assignCtrl.text = v ?? ''),
                dropdownColor: kCard,
                style: const TextStyle(color: Colors.white),
                decoration: kInputDecoration('Assign To Member', Icons.person_add_alt_1),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: _timeCtrl, style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Allocated Time (e.g. 3 Days)', Icons.schedule)),
          const SizedBox(height: 12),
          SwitchListTile(
            tileColor: kBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kBorder)),
            title: const Text('Mark as Urgent (+25 pts)'),
            value: _isUrgent, activeThumbColor: Colors.orangeAccent,
            onChanged: (v) => setM(() => _isUrgent = v),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _saving ? null : () async {
              if (_titleCtrl.text.trim().isEmpty || _service == null || _assignCtrl.text.trim().isEmpty
                  || (!_isInternal && _clientId == null)) {
                ScaffoldMessenger.of(bCtx).showSnackBar(const SnackBar(content: Text('Fill all required fields'))); return;
              }
              if (await isMonthLocked()) { ScaffoldMessenger.of(bCtx).showSnackBar(const SnackBar(content: Text('Month is locked'))); return; }
              setM(() => _saving = true);
              try {
                final spts = serviceWeights[_service!] ?? 0;
                final bpts = _isUrgent ? urgentBonus : 0;
                final docRef = await tasksCol.add({
                  'title': _titleCtrl.text.trim(),
                  'service': _service, 'assigned_to': _assignCtrl.text.trim(),
                  'allocated_time': _timeCtrl.text.trim(),
                  'is_urgent': _isUrgent, 'is_internal': _isInternal,
                  if (!_isInternal) 'client_id':   _clientId,
                  if (!_isInternal) 'client_name': _clientName,
                  'base_points': spts, 'bonus_points': bpts, 'total_points': spts + bpts,
                  'status': 'ASSIGNED',
                  'created_at': FieldValue.serverTimestamp(),
                  'created_by': FirebaseAuth.instance.currentUser?.uid,
                });
                await logEvent(type: 'TASK_CREATED', description: '"${_titleCtrl.text.trim()}" created', taskId: docRef.id, clientId: _isInternal ? null : _clientId);
                _titleCtrl.clear(); _timeCtrl.clear(); _assignCtrl.clear();
                setState(() { _clientId = _clientName = _service = null; _isUrgent = _isInternal = false; });
                if (bCtx.mounted) Navigator.pop(bCtx);
              } catch (e) {
                if (bCtx.mounted) ScaffoldMessenger.of(bCtx).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally { setM(() => _saving = false); }
            },
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Task'),
          )),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: clientsCol.orderBy('created_at', descending: true).snapshots(),
      builder: (_, clientSnap) {
        final clients = clientSnap.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot>(
          stream: tasksCol.where('status', isEqualTo: 'PENDING_VERIFICATION').snapshots(),
          builder: (_, pendSnap) {
            final pending = pendSnap.data?.docs ?? [];
            return ListView(padding: const EdgeInsets.all(16), children: [
              // ── Header ──
              Row(children: [
                Text('Admin Panel', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.add_task, size: 18), label: const Text('Create Task'),
                  style: FilledButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _showCreateTask(context, clients),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Pending Queue ──
              kSectionTitle('Pending Verification (${pending.length})'),
              if (pending.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No tasks awaiting review.', style: TextStyle(color: Colors.white38)))))
              else
                ...pending.map((doc) => _PendingCard(doc: doc)),

              const SizedBox(height: 20),
              // ── WFH Override ──
              kSectionTitle('Manual WFH Override'),
              const Text('Award +10 attendance points to a member for approved WFH.', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: usersCol.snapshots(),
                builder: (_, userSnap) {
                  final users = userSnap.data?.docs ?? [];
                  if (users.isEmpty) return const Text('No users found.', style: TextStyle(color: Colors.white38));
                  return Column(children: users.map((uDoc) {
                    final u = uDoc.data() as Map<String, dynamic>;
                    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
                      dense: true,
                      leading: CircleAvatar(backgroundColor: kAccent, radius: 16,
                        child: Text((u['name'] as String? ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                      title: Text(u['name'] as String? ?? uDoc.id, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${(u['points'] as num? ?? 0)} pts  •  ${u['role'] as String? ?? 'member'}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                      trailing: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32)),
                        onPressed: () async {
                          if (await isMonthLocked()) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Month is locked'))); return; }
                          await usersCol.doc(uDoc.id).set({'points': FieldValue.increment(attendancePoints), 'last_updated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                          await logEvent(type: 'WFH_OVERRIDE', description: 'WFH attendance awarded to ${u['name'] ?? uDoc.id}');
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+$attendancePoints pts awarded to ${u['name'] ?? uDoc.id}')));
                        },
                        child: const Text('Award WFH', style: TextStyle(fontSize: 12)),
                      ),
                    ));
                  }).toList());
                },
              ),

              const SizedBox(height: 20),
              // ── All Tasks ──
              StreamBuilder<QuerySnapshot>(
                stream: tasksCol.orderBy('created_at', descending: true).snapshots(),
                builder: (_, allSnap) {
                  final all = allSnap.data?.docs ?? [];
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    kSectionTitle('All Tasks (${all.length})'),
                    ...all.map((doc) {
                      final d      = doc.data() as Map<String, dynamic>;
                      final status = d['status'] as String? ?? 'ASSIGNED';
                      return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
                        dense: true,
                        title: Text(d['title'] ?? 'Untitled', style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${(d['service'] as String? ?? '-').replaceAll('_', ' ')}  •  ${d['is_internal'] == true ? 'Internal' : (d['client_name'] ?? '-')}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        trailing: statusBadge(status),
                      ));
                    }),
                  ]);
                },
              ),
            ]);
          },
        );
      },
    );
  }
}

// ─── Pending Verification Card ────────────────────────────────────────────────
class _PendingCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _PendingCard({required this.doc});
  @override
  Widget build(BuildContext context) {
    final d       = doc.data() as Map<String, dynamic>;
    final service = d['service'] as String? ?? '';
    final isUrgent= d['is_urgent'] == true;
    final spts    = serviceWeights[service] ?? 0;
    final totalPts= spts + (isUrgent ? urgentBonus : 0);

    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(d['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 4),
      Text('${service.replaceAll('_', ' ')}  •  ${d['is_internal'] == true ? 'Internal' : (d['client_name'] ?? '-')}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      Text('Assigned to: ${d['assigned_to'] ?? '-'}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      Row(children: [
        const Icon(Icons.stars_rounded, size: 13, color: kMuted),
        const SizedBox(width: 4),
        Text('$totalPts pts  ($spts base${isUrgent ? " +$urgentBonus urgent" : ""})', style: const TextStyle(color: kMuted, fontSize: 12)),
        if (isUrgent) ...[const SizedBox(width: 8), const Text('⚡ URGENT', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w600))],
      ]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(
          onPressed: () async {
            await tasksCol.doc(doc.id).update({'status': 'ASSIGNED', 'rejected_at': FieldValue.serverTimestamp()});
            await logEvent(type: 'TASK_REJECTED', description: '"${d['title']}" rejected by admin', taskId: doc.id, clientId: d['client_id'] as String?);
          },
          child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            if (await isMonthLocked()) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Month is locked'))); return; }
            await tasksCol.doc(doc.id).update({
              'status': 'VERIFIED',
              'verified_at': FieldValue.serverTimestamp(),
              'verified_by': FirebaseAuth.instance.currentUser?.uid,
              'awarded_points': totalPts,
            });
            final uid = d['assigned_to'] as String?;
            if (uid != null && uid.isNotEmpty) {
              await usersCol.doc(uid).set({'points': FieldValue.increment(totalPts), 'last_updated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
            }
            await logEvent(type: 'TASK_VERIFIED', description: '"${d['title']}" verified (+$totalPts pts)', taskId: doc.id, clientId: d['client_id'] as String?);
          },
          child: Text('✓ Verify (+$totalPts pts)'),
        ),
      ]),
    ])));
  }
}
