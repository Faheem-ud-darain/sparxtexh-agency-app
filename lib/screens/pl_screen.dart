import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_constants.dart';

class FinancialOverviewScreen extends StatelessWidget {
  const FinancialOverviewScreen({super.key});

  void _showAddExpenseModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String expType = 'setup_cost';

    showPulseModal(context,
        title: 'Log Expense',
        child: StatefulBuilder(
            builder: (ctx, setM) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'setup_cost',
                              label: Text('SETUP COST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                              icon: Icon(Icons.build_circle_outlined, size: 18)),
                          ButtonSegment(
                              value: 'team_expense',
                              label: Text('TEAM EXPENSE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                              icon: Icon(Icons.group_outlined, size: 18)),
                        ],
                        selected: {expType},
                        onSelectionChanged: (s) => setM(() => expType = s.first),
                        style: SegmentedButton.styleFrom(
                          backgroundColor: kBg,
                          selectedBackgroundColor: kAccent,
                          selectedForegroundColor: kText,
                          foregroundColor: kMuted,
                          side: const BorderSide(color: kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(controller: nameCtrl, style: const TextStyle(color: kText), decoration: kInputDecoration('Description', Icons.label_outline)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: kText),
                          decoration: kInputDecoration('Amount (PKR)', Icons.monetization_on)),
                      const SizedBox(height: 40),
                      SizedBox(
                          width: double.infinity,
                          child: kPrimaryButton(
                            label: 'LOG EXPENDITURE',
                            icon: Icons.receipt_long_rounded,
                            onPressed: () async {
                              final desc = nameCtrl.text.trim();
                              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                              if (desc.isEmpty || amount <= 0) {
                                showSystemNotification(context, 'PLEASE FILL ALL REQUIRED DATA', isError: true);
                                return;
                              }
                              if (await isMonthLocked()) {
                                showSystemNotification(context, 'MONTH IS SECURED AND LOCKED', isError: true);
                                return;
                              }
                              await expensesCol.add({
                                'name': desc,
                                'amount': amount,
                                'type': expType,
                                'added_by': FirebaseAuth.instance.currentUser?.uid,
                                'timestamp': FieldValue.serverTimestamp(),
                                'month': DateFormat('yyyy-MM').format(DateTime.now()),
                              });
                              await logEvent(
                                  type: 'EXPENSE_ADDED',
                                  description: '${expType == 'setup_cost' ? 'Setup Cost' : 'Team Expense'}: $desc',
                                  amount: amount);
                              if (context.mounted) {
                                Navigator.pop(context);
                                showSystemNotification(context, 'SPEND LOGGED SUCCESSFULLY');
                              }
                            },
                          )),
                    ])));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final curMonth = DateFormat('yyyy-MM').format(DateTime.now());

    return StreamBuilder<DocumentSnapshot>(
      stream: usersCol.doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final bool isAdmin = (userData?['role'] == 'admin') || (uid == kSuperAdminUID);

        return StreamBuilder<QuerySnapshot>(
          stream: paymentsCol.where('month', isEqualTo: curMonth).snapshots(),
          builder: (_, paySnap) {
            final payments = paySnap.data?.docs ?? [];
            double totalRevenue = 0.0;
            for (final p in payments) {
              totalRevenue += ((p.data() as Map<String, dynamic>)['amount'] as num? ?? 0.0).toDouble();
            }

            return StreamBuilder<QuerySnapshot>(
              stream: expensesCol.where('month', isEqualTo: curMonth).snapshots(),
              builder: (_, expSnap) {
                final expenses = expSnap.data?.docs ?? [];
                double teamExpenses = 0.0;
                Map<String, double> userSpends = {};
                for (final doc in expenses) {
                  final d = doc.data() as Map<String, dynamic>;
                  final amt = (d['amount'] as num? ?? 0).toDouble();
                  final addedBy = d['added_by'] as String? ?? 'unknown';
                  teamExpenses += amt;
                  userSpends[addedBy] = (userSpends[addedBy] ?? 0) + amt;
                }

                final totalExp = teamExpenses;
                final netProfit = totalRevenue - totalExp;

                return StreamBuilder<QuerySnapshot>(
                  stream: usersCol.orderBy('points', descending: true).snapshots(),
                  builder: (_, userSnap) {
                    final users = userSnap.data?.docs ?? [];
                    int totalPts = 0;
                    for (final u in users) {
                      totalPts += ((u.data() as Map<String, dynamic>)['points'] as num? ?? 0).toInt();
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: clientsCol.snapshots(),
                      builder: (_, clientSnap) {
                        final clients = clientSnap.data?.docs ?? [];
                        bool hasOverdue = false;
                        for (final c in clients) {
                          final cd = c.data() as Map<String, dynamic>;
                          final nextP = (cd['next_payment_date'] as Timestamp?)?.toDate();
                          final pending = (cd['pending_balance'] as num? ?? 0).toDouble();
                          if (nextP != null && nextP.isBefore(DateTime.now()) && pending > 0) {
                            hasOverdue = true;
                            break;
                          }
                        }

                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_rounded, color: kAccent, size: 28),
                                const SizedBox(width: 12),
                                Text('FINANCIALS',
                                    style: GoogleFonts.syncopate(
                                        color: kText, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
                              ],
                            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
                            const SizedBox(height: 32),
                            if (isAdmin)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        final batch = FirebaseFirestore.instance.batch();
                                        final pSnap = await paymentsCol.get();
                                        for (var doc in pSnap.docs) {
                                          batch.delete(doc.reference);
                                        }
                                        final eSnap = await expensesCol.get();
                                        for (var doc in eSnap.docs) {
                                          batch.delete(doc.reference);
                                        }
                                        await batch.commit();
                                        if (context.mounted) showSystemNotification(context, 'FINANCIAL REPOSITORY PURGED');
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
                                            const Icon(Icons.refresh_rounded, size: 16, color: kError),
                                            const SizedBox(width: 8),
                                            Text('RESET FINANCIALS',
                                                style: GoogleFonts.syncopate(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    color: kError,
                                                    letterSpacing: 1)),
                                          ],
                                        ),
                                      ),
                                    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
                                  ],
                                ),
                              ),
                            if (hasOverdue) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: kError.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: kError.withValues(alpha: 0.3))),
                                child: Row(children: [
                                  const Icon(Icons.warning_amber_rounded, color: kError, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text('OVERDUE PAYMENTS DETECTED! Ensure billing integrity.',
                                          style: GoogleFonts.inter(
                                              color: kError, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
                                ]),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // ── Premium Profit Dashboard Card ──
                            Container(
                              width: double.infinity,
                              decoration: kBentoDecoration(),
                              padding: const EdgeInsets.all(28),
                              child: Column(children: [
                                Text(DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase(),
                                    style: GoogleFonts.inter(
                                        letterSpacing: 1.5,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: kText.withValues(alpha: 0.5))),
                                const SizedBox(height: 16),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Icon(Icons.account_balance_wallet_rounded, color: kText, size: 32),
                                  const SizedBox(width: 16),
                                  Text(formatPKR(netProfit),
                                      style: GoogleFonts.inter(
                                          fontSize: 36, fontWeight: FontWeight.w900, color: kText, letterSpacing: -1.5)),
                                ]),
                                const SizedBox(height: 8),
                                Text('NET PROFIT POOL',
                                    style: GoogleFonts.inter(
                                        fontSize: 10, fontWeight: FontWeight.w900, color: kAccent, letterSpacing: 2)),
                                const Divider(color: Colors.white10, height: 48),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                  _miniStat('Revenue', formatPKR(totalRevenue)),
                                  Container(width: 1, height: 30, color: Colors.white10),
                                  _miniStat('Expenses', formatPKR(totalExp)),
                                ]),
                              ]),
                            ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                            const SizedBox(height: 24),
                            Row(children: [
                              Expanded(
                                  child: kPrimaryButton(
                                label: 'LOG NEW SPEND',
                                icon: Icons.add_rounded,
                                color: kGold,
                                onPressed: () => _showAddExpenseModal(context),
                              )),
                            ]),

                            const SizedBox(height: 32),
                            _FinancialSummary(revenue: totalRevenue, expenses: totalExp),

                            const SizedBox(height: 48),
                            Text('PROFIT VS BURN',
                                style:
                                    GoogleFonts.syncopate(fontSize: 14, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1)),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                duration: 800.ms,
                                curve: Curves.easeInOutBack,
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 50,
                                  sections: [
                                    PieChartSectionData(
                                      color: kAccent,
                                      value: netProfit > 0 ? netProfit : 0,
                                      title: 'PROFIT',
                                      radius: 60,
                                      titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                                    ),
                                    PieChartSectionData(
                                      color: kError,
                                      value: totalExp > 0 ? totalExp : 0,
                                      title: 'BURN',
                                      radius: 60,
                                      titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: kText),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(delay: 400.ms, duration: 800.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),

                            const SizedBox(height: 48),
                            Text('PAYOUT FORECAST',
                                style:
                                    GoogleFonts.syncopate(fontSize: 14, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1)),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 250,
                              child: BarChart(
                                duration: 800.ms,
                                curve: Curves.easeInOutBack,
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: netProfit > 0 ? netProfit : 100,
                                  barTouchData: BarTouchData(enabled: false),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (double value, TitleMeta meta) {
                                          if (value.toInt() >= users.length) return const SizedBox.shrink();
                                          final name =
                                              (users[value.toInt()].data() as Map<String, dynamic>)['name']?.toString() ?? '?';
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 12.0),
                                            child: Text(name.split(' ').first.toUpperCase(),
                                                style: GoogleFonts.inter(color: kMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  barGroups: users.asMap().entries.map((e) {
                                    final ud = e.value.data() as Map<String, dynamic>;
                                    final pts = (ud['points'] as num? ?? 0).toInt();
                                    final pay = calculatePayout(
                                        userPoints: pts, totalAgencyPoints: totalPts, netProfitPool: netProfit);
                                    return BarChartGroupData(
                                      x: e.key,
                                      barRods: [
                                        BarChartRodData(
                                          toY: pay > 0 ? pay : 0,
                                          color: kGold,
                                          width: 20,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                        )
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ).animate().fadeIn(delay: 600.ms, duration: 800.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                            const SizedBox(height: 48),
                            Text('CONTRIBUTION VS EARNINGS',
                                style:
                                    GoogleFonts.syncopate(fontSize: 14, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1)),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 250,
                              child: BarChart(
                                duration: 800.ms,
                                curve: Curves.easeInOutBack,
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  barTouchData: BarTouchData(enabled: false),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (double value, TitleMeta meta) {
                                          if (value.toInt() >= users.length) return const SizedBox.shrink();
                                          final name =
                                              (users[value.toInt()].data() as Map<String, dynamic>)['name']?.toString() ?? '?';
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 12.0),
                                            child: Text(name.split(' ').first.toUpperCase(),
                                                style: GoogleFonts.inter(color: kMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  barGroups: users.asMap().entries.map((e) {
                                    final ud = e.value.data() as Map<String, dynamic>;
                                    final uid = e.value.id;
                                    final pts = (ud['points'] as num? ?? 0).toInt();
                                    final pay = calculatePayout(
                                        userPoints: pts, totalAgencyPoints: totalPts, netProfitPool: netProfit);
                                    final spend = userSpends[uid] ?? 0.0;
                                    return BarChartGroupData(
                                      x: e.key,
                                      barRods: [
                                        BarChartRodData(
                                          toY: spend > 0 ? spend : 0.1,
                                          color: kError,
                                          width: 10,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        ),
                                        BarChartRodData(
                                          toY: pay > 0 ? pay : 0.1,
                                          color: kAccent,
                                          width: 10,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        )
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ).animate().fadeIn(delay: 800.ms, duration: 800.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _chartLegend('Spend', kError),
                                const SizedBox(width: 24),
                                _chartLegend('Earnings', kAccent),
                              ],
                            ),

                            const SizedBox(height: 48),
                            Text('LIVE LEADERBOARD',
                                style:
                                    GoogleFonts.syncopate(fontSize: 14, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1)),
                            const SizedBox(height: 32),
                            if (users.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: kGlowDecoration(color: kMuted, borderRadius: 28),
                                child: Center(
                                    child: Text('NO PAYOUT DATA YET',
                                        style: GoogleFonts.inter(
                                            color: kMuted, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                              ),
                            ...users.asMap().entries.map((e) {
                              final rank = e.key + 1;
                              final ud = e.value.data() as Map<String, dynamic>;
                              final pts = (ud['points'] as num? ?? 0).toInt();
                              final pay =
                                  calculatePayout(userPoints: pts, totalAgencyPoints: totalPts, netProfitPool: netProfit);
                              return _LeaderboardItem(rank: rank, name: ud['name'] ?? e.value.id, points: pts, payout: pay)
                                  .animate()
                                  .fadeIn(delay: (400 + (e.key * 100)).ms, duration: 400.ms)
                                  .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
                            }),

                            const SizedBox(height: 48),
                            Text('CLIENTS',
                                style:
                                    GoogleFonts.syncopate(fontSize: 14, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1)),
                            const SizedBox(height: 32),
                            if (clients.isEmpty)
                              Center(
                                  child: Text('NO CLIENTS ACTIVE',
                                      style: GoogleFonts.inter(color: kMuted, fontSize: 12, fontWeight: FontWeight.w900)))
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: clients.length,
                                itemBuilder: (context, idx) => _ClientCard(doc: clients[idx], netProfit: netProfit),
                              ),
                            const SizedBox(height: 48),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _miniStat(String label, String value) => Column(children: [
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: kText, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: kText.withValues(alpha: 0.3), letterSpacing: 1)),
      ]);

  Widget _chartLegend(String label, Color color) => Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, color: kMuted, fontWeight: FontWeight.w900)),
      ]);
}

class _LeaderboardItem extends StatelessWidget {
  final int rank, points;
  final String name;
  final double payout;
  const _LeaderboardItem({required this.rank, required this.name, required this.points, required this.payout});

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? kGold
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : kMuted.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder.withValues(alpha: 0.05))),
      ),
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          Icon(Icons.shield_rounded, color: rankColor.withValues(alpha: 0.15), size: 48),
          Text('$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
        const SizedBox(width: 16),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: kText, fontSize: 14)),
          const SizedBox(height: 4),
          Text('$points POINTS EARNED'.toUpperCase(),
              style: GoogleFonts.inter(color: kMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(formatPKR(payout),
              style: GoogleFonts.inter(color: kAccent, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)),
          Text('EST. PAYOUT'.toUpperCase(),
              style: GoogleFonts.inter(color: kText.withValues(alpha: 0.2), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ]),
    );
  }
}

class _ClientCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final double netProfit;
  const _ClientCard({required this.doc, required this.netProfit});
  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data() as Map<String, dynamic>;
    final received = (d['amount_received'] as num? ?? 0).toDouble();
    final total = (d['total_project_value'] as num? ?? 0).toDouble();
    final pending = total - received;
    final dueTs = d['due_date'] as Timestamp?;
    final dueDate = dueTs?.toDate();
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          onTap: () => setState(() => _expanded = !_expanded),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: (isOverdue ? kError : kAccent).withValues(alpha: 0.1),
            child: Text((d['name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                style: TextStyle(color: isOverdue ? kError : kAccent, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          title: Text(d['name'] ?? 'Unnamed', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: kText)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(isOverdue ? 'BILLING OVERDUE' : 'PROGRESS: ${((received / total) * 100).toInt()}%',
                style: GoogleFonts.inter(color: isOverdue ? kError : kMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatPKR(pending),
                style: GoogleFonts.inter(color: kText, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.5)),
            Text('PENDING'.toUpperCase(), style: GoogleFonts.inter(color: kText.withValues(alpha: 0.2), fontSize: 9, fontWeight: FontWeight.w900)),
          ]),
        ),
        if (_expanded) ...[
          const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
          _ClientHistory(clientId: widget.doc.id),
          const SizedBox(height: 16),
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
        if (docs.isEmpty)
          return Padding(
              padding: const EdgeInsets.all(20),
              child: Text('NO RECENT ACTIVITY',
                  style: GoogleFonts.inter(color: kMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)));
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
                children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: kAccent),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text((d['description'] ?? '').toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10, color: kText, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
                  ]));
            }).toList()));
      },
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  final double revenue, expenses;
  const _FinancialSummary({required this.revenue, required this.expenses});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: kAccent.withValues(alpha: 0.03), blurRadius: 40, spreadRadius: -20),
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics_rounded, color: kAccent, size: 20),
          const SizedBox(width: 12),
          Text('STRATEGIC SUMMARY', style: GoogleFonts.syncopate(fontSize: 14, fontWeight: FontWeight.w900, color: kText)),
        ]),
        const SizedBox(height: 24),
        _summaryRow('CASH INFLOW', revenue, kAccent),
        const SizedBox(height: 12),
        _summaryRow('OPERATIONAL SPEND', expenses, kError),
        const Divider(color: Colors.white10, height: 48),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('NET PROFIT POOL',
              style: GoogleFonts.inter(color: kMuted, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          Text(formatPKR(revenue - expenses),
              style: GoogleFonts.inter(color: kAccent, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        ]),
        const SizedBox(height: 16),
        Text('*Operational cost factors include Rent, Infrastructure, and Core Overheads.',
            style: GoogleFonts.inter(color: kText.withValues(alpha: 0.1), fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _summaryRow(String label, double val, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: kMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          Text(formatPKR(val), style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      );
}
