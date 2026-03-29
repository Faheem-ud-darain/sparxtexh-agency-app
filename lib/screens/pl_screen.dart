import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../app_constants.dart';

class FinancialOverviewScreen extends StatelessWidget {
  const FinancialOverviewScreen({super.key});

  void _showAddClientModal(BuildContext context) {
    final nameCtrl     = TextEditingController();
    final valueCtrl    = TextEditingController();
    final receivedCtrl = TextEditingController();
    final notesCtrl    = TextEditingController();
    DateTime? startDate;
    DateTime? dueDate;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add New Client', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Client Name', Icons.business)),
          const SizedBox(height: 12),
          TextField(controller: valueCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Total Project Value (PKR)', Icons.monetization_on)),
          const SizedBox(height: 12),
          TextField(controller: receivedCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Amount Received (PKR)', Icons.payments)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(startDate == null ? 'Start Date' : DateFormat('dd MMM').format(startDate!), style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kBorder), foregroundColor: Colors.white70),
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (d != null) setM(() => startDate = d);
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 16),
              label: Text(dueDate == null ? 'Due Date' : DateFormat('dd MMM').format(dueDate!), style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kBorder), foregroundColor: Colors.white70),
              onPressed: () async {
                final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (d != null) setM(() => dueDate = d);
              },
            )),
          ]),
          const SizedBox(height: 12),
          TextField(controller: notesCtrl, style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Notes (optional)', Icons.notes)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Client name required'))); return; }
              final value    = double.tryParse(valueCtrl.text.trim()) ?? 0.0;
              final received = double.tryParse(receivedCtrl.text.trim()) ?? 0.0;
              if (await isMonthLocked()) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Month is locked'))); return; }
              final docRef = await clientsCol.add({
                'name': name, 'total_project_value': value, 'amount_received': received,
                'pending_balance': value - received,
                if (startDate != null) 'start_date': Timestamp.fromDate(startDate!),
                if (dueDate   != null) 'due_date':   Timestamp.fromDate(dueDate!),
                'notes': notesCtrl.text.trim(),
                'created_at': FieldValue.serverTimestamp(),
              });
              await logEvent(type: 'CLIENT_ADDED', description: 'Client "$name" added', clientId: docRef.id, amount: value);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Client'),
          )),
        ])),
      )),
    );
  }

  void _showAddExpenseModal(BuildContext context) {
    final nameCtrl   = TextEditingController();
    final amountCtrl = TextEditingController();
    String expType = 'setup_cost';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Log Expense', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'setup_cost',   label: Text('Setup Cost'),    icon: Icon(Icons.build_circle_outlined)),
              ButtonSegment(value: 'team_expense', label: Text('Team Expense'),  icon: Icon(Icons.group_outlined)),
            ],
            selected: {expType},
            onSelectionChanged: (s) => setM(() => expType = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl,   style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Description', Icons.label_outline)),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: kInputDecoration('Amount (PKR)', Icons.monetization_on)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () async {
              final desc   = nameCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (desc.isEmpty || amount <= 0) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Fill all fields'))); return; }
              if (await isMonthLocked()) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Month is locked'))); return; }
              await expensesCol.add({
                'name': desc, 'amount': amount, 'type': expType,
                'added_by': FirebaseAuth.instance.currentUser?.uid,
                'timestamp': FieldValue.serverTimestamp(),
                'month': DateFormat('yyyy-MM').format(DateTime.now()),
              });
              await logEvent(type: 'EXPENSE_ADDED', description: '${expType == 'setup_cost' ? 'Setup Cost' : 'Team Expense'}: $desc', amount: amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Log Expense'),
          )),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curMonth = DateFormat('yyyy-MM').format(DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: clientsCol.snapshots(),
      builder: (_, clientSnap) {
        final clients = clientSnap.data?.docs ?? [];
        double totalRevenue = 0;
        for (final doc in clients) {
          totalRevenue += ((doc.data() as Map<String, dynamic>)['amount_received'] as num? ?? 0).toDouble();
        }
        return StreamBuilder<QuerySnapshot>(
          stream: expensesCol.where('month', isEqualTo: curMonth).snapshots(),
          builder: (_, expSnap) {
            final expenses = expSnap.data?.docs ?? [];
            double setupCosts = 0, teamExpenses = 0;
            for (final doc in expenses) {
              final d = doc.data() as Map<String, dynamic>;
              final amt = (d['amount'] as num? ?? 0).toDouble();
              if (d['type'] == 'setup_cost')   setupCosts   += amt;
              if (d['type'] == 'team_expense') teamExpenses += amt;
            }
            final totalExp  = setupCosts + teamExpenses;
            final netProfit = totalRevenue - totalExp;

            return StreamBuilder<QuerySnapshot>(
              stream: usersCol.orderBy('points', descending: true).snapshots(),
              builder: (_, userSnap) {
                final users = userSnap.data?.docs ?? [];
                int totalPts = 0;
                for (final u in users) { totalPts += ((u.data() as Map<String, dynamic>)['points'] as num? ?? 0).toInt(); }

                return ListView(padding: const EdgeInsets.all(16), children: [
                  // ── Premium Profit Dashboard Card ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [kAccent.withValues(alpha: 0.8), kAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Text(DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase(), style: GoogleFonts.inter(letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70)),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Text(formatPKR(netProfit), style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                      const SizedBox(height: 8),
                      Text('NET PROFIT POOL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 1)),
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _miniStat('Revenue', formatPKR(totalRevenue)),
                        Container(width: 1, height: 30, color: Colors.white24),
                        _miniStat('Expenses', formatPKR(totalExp)),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16), label: const Text('Setup Cost'),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kBorder), foregroundColor: Colors.white70, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => _showAddExpenseModal(context),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16), label: const Text('Team Spend'),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: kBorder), foregroundColor: Colors.white70, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => _showAddExpenseModal(context),
                    )),
                  ]),

                  const SizedBox(height: 24),
                  Row(children: [
                    kSectionTitle('Active Clients'),
                    const Spacer(),
                    TextButton.icon(onPressed: () => _showAddClientModal(context), icon: const Icon(Icons.add_circle_outline, size: 18), label: const Text('Add Client')),
                  ]),
                  if (clients.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No active clients.', style: TextStyle(color: Colors.white38)))),
                  ...clients.map((doc) => _ClientCard(doc: doc, netProfit: netProfit)),

                  const SizedBox(height: 24),
                  kSectionTitle('Live Leaderboard'),
                  if (users.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No payout data yet.', style: TextStyle(color: Colors.white38))))),
                  ...users.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final ud   = e.value.data() as Map<String, dynamic>;
                    final pts  = (ud['points'] as num? ?? 0).toInt();
                    final pay  = calculatePayout(userPoints: pts, totalAgencyPoints: totalPts, netProfitPool: netProfit);
                    return _LeaderboardItem(rank: rank, name: ud['name'] ?? e.value.id, points: pts, payout: pay);
                  }),
                ]);
              },
            );
          },
        );
      },
    );
  }

  Widget _miniStat(String label, String value) => Column(children: [
    Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
    Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white54)),
  ]);
}

class _LeaderboardItem extends StatelessWidget {
  final int rank, points;
  final String name;
  final double payout;
  const _LeaderboardItem({required this.rank, required this.name, required this.points, required this.payout});

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : rank == 3 ? const Color(0xFFCD7F32) : kMuted.withValues(alpha: 0.5);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          Icon(Icons.shield_rounded, color: rankColor.withValues(alpha: 0.15), size: 40),
          Text('$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          Text('$points points earned', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(formatPKR(payout), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 15)),
          const Text('EST. PAYOUT', style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
      ]),
    );
  }
}

class _ClientCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final double netProfit;
  const _ClientCard({required this.doc, required this.netProfit});
  @override State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final d        = widget.doc.data() as Map<String, dynamic>;
    final received = (d['amount_received']      as num? ?? 0).toDouble();
    final total    = (d['total_project_value']   as num? ?? 0).toDouble();
    final pending  = total - received;
    final dueTs    = d['due_date'] as Timestamp?;
    final dueDate  = dueTs?.toDate();
    final isOverdue= dueDate != null && dueDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
      child: Column(children: [
        ListTile(
          onTap: () => setState(() => _expanded = !_expanded),
          leading: CircleAvatar(backgroundColor: kAccent.withValues(alpha: 0.2), child: Text((d['name'] as String? ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(color: kAccent, fontWeight: FontWeight.w800))),
          title: Text(d['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Text(isOverdue ? 'OVERDUE' : 'Payment: ${((received / total) * 100).toInt()}%', style: TextStyle(color: isOverdue ? Colors.redAccent : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatPKR(pending), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const Text('PENDING', style: TextStyle(color: Colors.white24, fontSize: 9)),
          ]),
        ),
        if (_expanded) ...[
          const Divider(color: kBorder, height: 1),
          _ClientHistory(clientId: widget.doc.id),
          const SizedBox(height: 8),
        ]
      ]),
    );
  }
}

class _ClientHistory extends StatelessWidget {
  final String clientId;
  const _ClientHistory({required this.clientId});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: historyCol.where('client_id', isEqualTo: clientId).orderBy('timestamp', descending: true).limit(5).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No recent activity.', style: TextStyle(color: Colors.white38, fontSize: 12)));
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            const Icon(Icons.check_circle_outline, size: 14, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(d['description'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white60))),
          ]));
        }).toList()));
      },
    );
  }
}
