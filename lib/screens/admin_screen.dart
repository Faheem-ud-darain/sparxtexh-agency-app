import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  void dispose() { 
    _titleCtrl.dispose(); 
    _timeCtrl.dispose(); 
    _assignCtrl.dispose(); 
    _broadcastTitle.dispose();
    _broadcastBody.dispose();
    super.dispose(); 
  }

  final _broadcastTitle = TextEditingController();
  final _broadcastBody  = TextEditingController();

  // ─── Create Task Modal ──────────────────────────────────────────────────────
  void _showCreateTask(BuildContext ctx, List<QueryDocumentSnapshot> clients) {
    showPulseModal(ctx, title: 'Assign Mission', child: StatefulBuilder(builder: (bCtx, setM) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            tileColor: kBg.withValues(alpha: 0.5), 
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kBorder)),
            title: Text('INTERNAL OPS', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: kText)),
            subtitle: Text('Not linked to a client', style: GoogleFonts.inter(fontSize: 11, color: kMuted)),
            value: _isInternal, activeThumbColor: kAccent,
            onChanged: (v) => setM(() { _isInternal = v; if (v) { _clientId = null; _clientName = null; } }),
          ),
          const SizedBox(height: 24),
          
          TextField(controller: _titleCtrl, style: const TextStyle(color: kText), decoration: kInputDecoration('Task Title', Icons.title_rounded)),
          const SizedBox(height: 24),

          if (!_isInternal) ...[
            DashboardDropDownField<String>(
              label: 'Strategic Client',
              icon: Icons.business_rounded,
              value: _clientId,
              items: clients.map((d) => DropdownMenuItem(value: d.id, child: Text((d.data() as Map)['name'] ?? 'Unknown', style: const TextStyle(color: kText, fontSize: 13)))).toList(),
              onChanged: (v) { setM(() { _clientId = v; _clientName = (clients.firstWhere((d) => d.id == v).data() as Map)['name'] as String?; }); },
            ),
            const SizedBox(height: 24),
          ],

          DashboardDropDownField<String>(
            label: 'Tactical Service',
            icon: Icons.design_services_rounded,
            value: _service,
            items: serviceWeights.keys.map((s) => DropdownMenuItem(value: s, child: Text('${s.replaceAll('_', ' ')} (${serviceWeights[s]} pts)', style: const TextStyle(color: kText, fontSize: 13)))).toList(),
            onChanged: (v) => setM(() => _service = v),
          ),
          const SizedBox(height: 24),

          StreamBuilder<QuerySnapshot>(
            stream: usersCol.snapshots(),
            builder: (context, snapshot) {
              final users = snapshot.data?.docs ?? [];
              return DashboardDropDownField<String>(
                label: 'Assign Operator',
                icon: Icons.person_add_alt_1_rounded,
                value: _assignCtrl.text.isEmpty ? null : _assignCtrl.text,
                items: users.map((u) {
                  final data = u.data() as Map<String, dynamic>;
                  return DropdownMenuItem(value: u.id, child: Text(data['name'] ?? u.id, style: const TextStyle(color: kText, fontSize: 13)));
                }).toList(),
                onChanged: (v) => setM(() => _assignCtrl.text = v ?? ''),
              );
            },
          ),
          const SizedBox(height: 24),

          TextField(controller: _timeCtrl, style: const TextStyle(color: kText), decoration: kInputDecoration('Deployment Window (e.g. 24H)', Icons.schedule_rounded)),
          const SizedBox(height: 24),

          SwitchListTile(
            tileColor: kBg.withValues(alpha: 0.5), 
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: kGold.withValues(alpha: 0.2))),
            title: Text('URGENT PRIORITY', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: kGold)),
            subtitle: Text('Adds +25 Bonus Points', style: GoogleFonts.inter(fontSize: 11, color: kGold.withValues(alpha: 0.7))),
            value: _isUrgent, activeThumbColor: kGold,
            onChanged: (v) => setM(() => _isUrgent = v),
          ),
          const SizedBox(height: 40),

          SizedBox(width: double.infinity, child: kPrimaryButton(
            label: 'DEPLOY TASK',
            icon: Icons.rocket_launch_rounded,
            onPressed: _saving ? null : () async {
              if (_titleCtrl.text.trim().isEmpty || _service == null || _assignCtrl.text.trim().isEmpty || (!_isInternal && _clientId == null)) {
                showSystemNotification(bCtx, 'ALL CORE TACTICAL DATA REQUIRED', isError: true); return;
              }
              setM(() => _saving = true);
              try {
                await tasksCol.add({
                  'title': _titleCtrl.text.trim(),
                  'service': _service,
                  'client_id': _clientId,
                  'client_name': _isInternal ? 'Internal' : _clientName,
                  'assigned_to': _assignCtrl.text,
                  'allocated_time': _timeCtrl.text.trim(),
                  'is_urgent': _isUrgent,
                  'status': 'ASSIGNED',
                  'created_at': FieldValue.serverTimestamp(),
                  'is_internal': _isInternal,
                });
                if (bCtx.mounted) Navigator.pop(bCtx); // Corrected to use bCtx (local modal context)
                if (bCtx.mounted) showSystemNotification(bCtx, 'CORE TASK DEPLOYED SUCCESSFULLY');
              } finally { 
                if (mounted) setState(() => _saving = false);
              }
            },
          )),
        ])));
  }

  void _showAddClientModal(BuildContext ctx) {
    final nameCtrl     = TextEditingController();
    final valueCtrl    = TextEditingController();
    final receivedCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '1');
    final notesCtrl    = TextEditingController();
    DateTime? startDate, nextPayDate;

    showPulseModal(ctx, title: 'Onboard Partner', child: StatefulBuilder(builder: (bCtx, setM) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: kText), decoration: kInputDecoration('Client Name', Icons.business)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: valueCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: kText), decoration: kInputDecoration('Total Value', Icons.monetization_on))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: durationCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: kText), decoration: kInputDecoration('Contract (Mo)', Icons.repeat))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: receivedCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: kText), decoration: kInputDecoration('Initial Deposit (PKR)', Icons.payments)),
          const SizedBox(height: 24),
          
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(startDate == null ? 'START DATE' : DateFormat('dd MMM').format(startDate!), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kBorder), foregroundColor: kText, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (d != null) setM(() => startDate = d);
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.event_available, size: 16),
              label: Text(nextPayDate == null ? 'NEXT PAY' : DateFormat('dd MMM').format(nextPayDate!), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: kGold.withValues(alpha: 0.5)), foregroundColor: kGold, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (d != null) setM(() => nextPayDate = d);
              },
            )),
          ]),
          const SizedBox(height: 16),
          TextField(controller: notesCtrl, style: const TextStyle(color: kText), decoration: kInputDecoration('Strategic Notes', Icons.notes)),
          const SizedBox(height: 40),
          
          SizedBox(width: double.infinity, child: kPrimaryButton(
            label: 'INITIALIZE PARTNERSHIP',
            icon: Icons.handshake_rounded,
            color: kGold,
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final value    = double.tryParse(valueCtrl.text.trim()) ?? 0.0;
              final received = double.tryParse(receivedCtrl.text.trim()) ?? 0.0;
              final duration = int.tryParse(durationCtrl.text.trim()) ?? 1;
              try {
                final curMonth = DateFormat('yyyy-MM').format(DateTime.now());
                final docRef = await clientsCol.add({
                  'name': name, 'total_project_value': value, 'amount_received': received,
                  'pending_balance': value - received, 'contract_months': duration, 'month': curMonth,
                  if (startDate != null) 'start_date': Timestamp.fromDate(startDate!),
                  if (nextPayDate != null) 'next_payment_date': Timestamp.fromDate(nextPayDate!),
                  'notes': notesCtrl.text.trim(), 'created_at': FieldValue.serverTimestamp(),
                });
                if (received > 0) {
                  await paymentsCol.add({
                    'client_id': docRef.id, 'client_name': name, 'amount': received,
                    'month': curMonth, 'timestamp': FieldValue.serverTimestamp(), 'type': 'INITIAL_PAYMENT',
                  });
                }
                await logEvent(type: 'CLIENT_ADDED', description: 'Onboarded $name: Value ${formatPKR(value)}', clientId: docRef.id, amount: value);
                if (bCtx.mounted) {
                  Navigator.pop(bCtx); // Corrected to use bCtx
                  showSystemNotification(bCtx, 'PARTNER INITIATED: ${name.toUpperCase()}');
                }
              } catch (_) {}
            },
          )),
        ])));
  }

  void _showBroadcastModal(BuildContext ctx) {
    showPulseModal(ctx, title: 'Broadcast Alert', child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SEND ALERT TO ALL SYSTEM OPERATORS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: kAccent, letterSpacing: 1)),
      const SizedBox(height: 12),
      Text('This message will be distributed to every registered device via encrypted FCM channels.', style: GoogleFonts.inter(fontSize: 12, color: kMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 32),
      TextField(controller: _broadcastTitle, style: const TextStyle(color: kText), decoration: kInputDecoration('Broadcast Title', Icons.campaign_rounded)),
      const SizedBox(height: 16),
      TextField(controller: _broadcastBody, maxLines: 3, style: const TextStyle(color: kText), decoration: kInputDecoration('Message Body', Icons.chat_bubble_outline_rounded)),
      const SizedBox(height: 48),
      SizedBox(width: double.infinity, child: kPrimaryButton(
        label: 'TRANSMIT BROADCAST',
        icon: Icons.send_rounded,
        color: kAccent,
        onPressed: () async {
          final t = _broadcastTitle.text.trim();
          final b = _broadcastBody.text.trim();
          if (t.isEmpty || b.isEmpty) return;
          try {
            await notificationsCol.add({
              'title': t,
              'body': b,
              'timestamp': FieldValue.serverTimestamp(),
              'sender_uid': FirebaseAuth.instance.currentUser?.uid,
            });
              if (ctx.mounted) {
                _broadcastTitle.clear();
                _broadcastBody.clear();
                Navigator.of(ctx).pop(); // Specifically using Navigator.of(ctx) which might be descendant 
                showSystemNotification(ctx, 'BROADCAST TRANSMITTED SUCCESSFULLY');
              }
            } catch (_) {}
        },
      )),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: clientsCol.orderBy('created_at', descending: true).snapshots(),
      builder: (_, clientSnap) {
        final clients = clientSnap.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot>(
          stream: tasksCol.where('status', isEqualTo: 'PENDING_VERIFICATION').snapshots(),
          builder: (context, pendSnap) {
            final pending = pendSnap.data?.docs ?? [];
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── MASTER HEADER (Bento Grid) ──
                Row(
                  children: [
                    Expanded(child: AspectRatio(aspectRatio: 1, child: InkWell(
                      onTap: () => _showCreateTask(context, clients),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: kBentoDecoration(),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_task_rounded, size: 32, color: kAccent),
                          const SizedBox(height: 8),
                          Text('ASSIGN', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 9, color: kText, letterSpacing: 0.5)),
                        ])
                      )
                    ))).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(width: 12),
                    Expanded(child: AspectRatio(aspectRatio: 1, child: InkWell(
                      onTap: () => _showAddClientModal(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: kBentoDecoration(),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.person_add_rounded, size: 32, color: kGold),
                          const SizedBox(height: 8),
                          Text('PARTNER', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 9, color: kText, letterSpacing: 0.5)),
                        ])
                      )
                    ))).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(width: 12),
                    Expanded(child: AspectRatio(aspectRatio: 1, child: InkWell(
                      onTap: () => _showBroadcastModal(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: kBentoDecoration(),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.campaign_rounded, size: 32, color: kError),
                          const SizedBox(height: 8),
                          Text('ALERT', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 9, color: kText, letterSpacing: 0.5)),
                        ])
                      )
                    ))).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Admin Security Clearance ──
                if (true) ...[ 
                  StreamBuilder<QuerySnapshot>(
                    stream: usersCol.where('is_approved', isEqualTo: false).snapshots(),
                    builder: (_, userSnap) {
                      final pendingUsers = userSnap.data?.docs ?? [];
                      if (pendingUsers.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        kSectionTitle('SECURITY CLEARANCES'),
                        const SizedBox(height: 16),
                        ...pendingUsers.map((uDoc) {
                          final u = uDoc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: kGlowDecoration(color: kGold, borderRadius: 28),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: kBg, backgroundImage: u['photoUrl'] != null ? NetworkImage(u['photoUrl']) : null, child: u['photoUrl'] == null ? const Icon(Icons.person, color: kGold) : null),
                              title: Text(u['name'] ?? 'Infiltrator', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: kText)),
                              subtitle: Text(u['email'] ?? 'Encrypted', style: GoogleFonts.inter(fontSize: 11, color: kMuted)),
                              trailing: kPrimaryButton(label: 'APPROVE', color: kGold, onPressed: () async => await usersCol.doc(uDoc.id).update({'is_approved': true})),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ]);
                    },
                  ),
                ],

                if (pending.isNotEmpty) ...[
                  kSectionTitle('VERIFICATION VAULT'),
                  const SizedBox(height: 16),
                  ...pending.asMap().entries.map((e) => _PendingCard(doc: e.value).animate().fadeIn(delay: (e.key * 100).ms, duration: 400.ms).slideY(begin: 0.1, end: 0)),
                  const SizedBox(height: 32),
                ],

                kSectionTitle('PARTNER DIRECTORY'),
                const SizedBox(height: 16),
                if (clients.isEmpty)
                  Center(child: Text('Operational Silence.', style: GoogleFonts.inter(color: kMuted, fontSize: 13, fontWeight: FontWeight.w600)))
                else
                  ...clients.asMap().entries.map((e) => _AdminClientCard(doc: e.value).animate().fadeIn(delay: (e.key * 100).ms, duration: 400.ms).slideX(begin: 0.05, end: 0)),
              ],
            );
          },
        );
      },
    );
  }
}

class _PendingCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _PendingCard({required this.doc});
  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final isUrgent = d['is_urgent'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: kGlowDecoration(color: isUrgent ? kGold : kAccent, borderRadius: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(d['title'] ?? 'Untitled', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: kText))),
            if (isUrgent) const Icon(Icons.bolt_rounded, color: kGold, size: 20),
          ]),
          const SizedBox(height: 4),
          Text(d['client_name'] ?? 'Internal', style: GoogleFonts.inter(color: kAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: kPrimaryButton(label: 'REJECT', color: kError, onPressed: () async => await tasksCol.doc(doc.id).update({'status': 'ASSIGNED'}))),
            const SizedBox(width: 12),
            Expanded(child: kPrimaryButton(label: 'VERIFY', color: kSuccess, onPressed: () async {
              final spts = serviceWeights[d['service']] ?? 0;
              final pts = spts + (isUrgent ? urgentBonus : 0);
              await tasksCol.doc(doc.id).update({'status': 'VERIFIED'});
              if (d['assigned_to'] != null) await usersCol.doc(d['assigned_to']).update({'points': FieldValue.increment(pts)});
            })),
          ]),
        ]),
      ),
    );
  }
}

class _AdminClientCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _AdminClientCard({required this.doc});
  @override State<_AdminClientCard> createState() => _AdminClientCardState();
}

class _AdminClientCardState extends State<_AdminClientCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data() as Map<String, dynamic>;
    final total = (d['total_project_value'] as num?)?.toDouble() ?? 0.0;
    final received = (d['amount_received'] as num?)?.toDouble() ?? 0.0;
    final pending = total - received;
    final nextPTs = d['next_payment_date'] as Timestamp?;
    final nextPay = nextPTs?.toDate();
    final isOverdue = nextPay != null && nextPay.isBefore(DateTime.now()) && pending > 0;

    // Overdue alert removed

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: kGlowDecoration(color: isOverdue ? kError : kAccent, borderRadius: 28),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Container(width: 45, height: 45, decoration: BoxDecoration(color: isOverdue ? kError.withValues(alpha: 0.1) : kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(d['name'].toString().substring(0, 1).toUpperCase(), style: GoogleFonts.syncopate(color: isOverdue ? kError : kAccent, fontWeight: FontWeight.w900)))),
          title: Text(d['name'] ?? 'Unnamed', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: kText)),
          subtitle: Text('Pending: ${formatPKR(pending)}', style: GoogleFonts.inter(color: isOverdue ? kError : kGold, fontSize: 11, fontWeight: FontWeight.w900)),
          trailing: Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: kMuted),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                _infoRow('TOTAL VALUE', formatPKR(total)),
                _infoRow('AMOUNT PAID', formatPKR(received)),
                if (nextPay != null) _infoRow('NEXT PAYMENT', DateFormat('dd MMM yyyy').format(nextPay), color: isOverdue ? kError : kGold),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: kPrimaryButton(
                    label: 'PURGE', 
                    icon: Icons.delete_forever_rounded, 
                    color: kError, 
                    onPressed: () async {
                      try {
                        final batch = db.batch();
                        batch.delete(clientsCol.doc(widget.doc.id));
                        final pSnap = await paymentsCol.where('client_id', isEqualTo: widget.doc.id).get();
                        for (var doc in pSnap.docs) {
                          batch.delete(doc.reference);
                        }
                        final tSnap = await tasksCol.where('client_id', isEqualTo: widget.doc.id).get();
                        for (var doc in tSnap.docs) {
                          batch.delete(doc.reference);
                        }
                        final hSnap = await historyCol.where('client_id', isEqualTo: widget.doc.id).get();
                        for (var doc in hSnap.docs) {
                          batch.delete(doc.reference);
                        }
                        
                        await batch.commit();
                        await logEvent(type: 'CLIENT_PURGED', description: 'Decommissioned ${d['name']} and all associated tactical data.', amount: total);
                        if (context.mounted) showSystemNotification(context, 'ENTITY ${d['name'].toUpperCase()} DECOMMISSIONED');
                      } catch (e) {
                         if (context.mounted) showSystemNotification(context, 'DECOMMISSIONING FAILED: SYSTEM TIMEOUT', isError: true);
                      }
                    }
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: kPrimaryButton(
                    label: 'COMPLETED', 
                    icon: Icons.verified_rounded, 
                    color: kSuccess, 
                    onPressed: () async {
                      await clientsCol.doc(widget.doc.id).update({'status': 'COMPLETED', 'amount_received': total, 'pending_balance': 0});
                      await logEvent(type: 'DEAL_COMPLETED', description: 'Strategically verified ${d['name']} completion.', clientId: widget.doc.id, amount: total);
                      if (context.mounted) showSystemNotification(context, 'PARTNERSHIP VERIFIED AS COMPLETED');
                    }
                  )),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: kPrimaryButton(label: 'LEDGER', icon: Icons.add_card_rounded, onPressed: () => _recordPayment(context, widget.doc.id, d['name'], pending, nextPay))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _recordPayment(BuildContext context, String id, String name, double pending, DateTime? current) {
    final ctrl = TextEditingController();
    DateTime? nextD = current != null ? getNextCycleDate(current) : getNextCycleDate(DateTime.now());
    showPulseModal(context, title: 'Ledger Entry', child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: ctrl, keyboardType: TextInputType.number, style: GoogleFonts.syncopate(color: kSuccess, fontSize: 24, fontWeight: FontWeight.w900), decoration: kInputDecoration('Amount (PKR)', Icons.payments)),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, child: kPrimaryButton(label: 'CONFIRM SETTLEMENT', icon: Icons.check_circle_rounded, color: kSuccess, onPressed: () async {
          final amt = double.tryParse(ctrl.text.trim()) ?? 0.0;
          if (amt <= 0) return;
          await clientsCol.doc(id).update({'amount_received': FieldValue.increment(amt), 'pending_balance': FieldValue.increment(-amt), 'next_payment_date': Timestamp.fromDate(nextD)});
          await logEvent(type: 'PAYMENT', description: 'Recieved ${formatPKR(amt)} from $name', clientId: id, amount: amt);
          if (context.mounted) {
            Navigator.pop(context);
            showSystemNotification(context, 'SETTLEMENT CONFIRMED: ${formatPKR(amt)}');
          }
        })),
        const SizedBox(height: 16),
      ]));
  }

  Widget _infoRow(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: GoogleFonts.inter(color: kMuted, fontSize: 10, fontWeight: FontWeight.w900)), Text(v, style: GoogleFonts.inter(color: color ?? kText, fontSize: 12, fontWeight: FontWeight.w800))]));

  DateTime getNextCycleDate(DateTime current) => DateTime(current.year, current.month + 1, current.day);
}
