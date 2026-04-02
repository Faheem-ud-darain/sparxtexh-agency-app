import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app_constants.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // ── Service weights state ──────────────────────────────────────────────────
  final Map<String, TextEditingController> _weightCtrls = {
    for (final e in defaultServiceWeights.entries)
      e.key: TextEditingController(text: e.value.toString())
  };
  bool _savingWeights = false;

  // ── Month Lock ─────────────────────────────────────────────────────────────
  bool _monthLocked = false;

  @override
  void initState() {
    super.initState();
    _loadWeightsFromFirestore();
    _loadLockStatus();
  }

  Future<void> _loadWeightsFromFirestore() async {
    try {
      final doc = await serviceWeightsDoc.get();
      if (doc.exists) {
        final data = doc.data();
        data?.forEach((k, v) {
          if (_weightCtrls.containsKey(k)) _weightCtrls[k]!.text = v.toString();
        });
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _loadLockStatus() async {
    try {
      final doc = await appConfigDoc.get();
      if (doc.exists) setState(() => _monthLocked = (doc.data())?['month_locked'] == true);
    } catch (_) {}
  }

  Future<void> _saveWeights() async {
    setState(() => _savingWeights = true);
    try {
      final data = <String, int>{};
      _weightCtrls.forEach((k, ctrl) {
        final v = int.tryParse(ctrl.text.trim());
        if (v != null) data[k] = v;
      });
      await serviceWeightsDoc.set(data);
      serviceWeights = data; // update in-memory cache
      await logEvent(type: 'SETTINGS_UPDATED', description: 'Service weights updated by admin');
      if (mounted) showSystemNotification(context, 'SERVICE WEIGHTS CALIBRATED');
    } catch (e) {
      if (mounted) showSystemNotification(context, 'SYSTEM ERROR: $e', isError: true);
    } finally { setState(() => _savingWeights = false); }
  }

  Future<void> _toggleLock(bool locked) async {
    await appConfigDoc.set({'month_locked': locked}, SetOptions(merge: true));
    await logEvent(type: locked ? 'MONTH_LOCKED' : 'MONTH_UNLOCKED', description: 'Month ${locked ? 'locked' : 'unlocked'} by admin');
    setState(() => _monthLocked = locked);
    if (mounted) showSystemNotification(context, 'FINANCIAL PERIOD ${locked ? 'LOCKED' : 'UNLOCKED'}', isError: locked);
  }

  // ─── Archive snapshot ──────────────────────────────────────────────────────
  Future<void> _archiveMonth() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: kCard, title: const Text('Archive This Month?'),
      content: const Text('This will save a summary of the current month\'s data and clear the activity log. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
      ],
    ));
    if (confirm != true) return;
    try {
      // Read current month data
      final curMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final clientsSnap  = await clientsCol.get();
      final usersSnap    = await usersCol.get();
      final expensesSnap = await expensesCol.where('month', isEqualTo: curMonth).get();
      double totalRevenue = 0, setupCosts = 0, teamExpenses = 0;
      for (final d in clientsSnap.docs) { totalRevenue += ((d.data() as Map)['amount_received'] as num? ?? 0).toDouble(); }
      for (final d in expensesSnap.docs) {
        final data = d.data();
        final amt = (data['amount'] as num? ?? 0).toDouble();
        if (data['type'] == 'setup_cost') {
          setupCosts += amt;
        } else {
          teamExpenses += amt;
        }
      }
      final userSummaries = usersSnap.docs.map((d) {
        final data = d.data();
        return {'uid': d.id, 'name': data['name'], 'points': data['points'] ?? 0};
      }).toList();
      // Write archive
      await db.collection('monthly_archives').doc(curMonth).set({
        'month': curMonth,
        'archived_at': FieldValue.serverTimestamp(),
        'total_revenue': totalRevenue,
        'setup_costs': setupCosts,
        'team_expenses': teamExpenses,
        'net_profit': totalRevenue - setupCosts - teamExpenses,
        'user_summaries': userSummaries,
        'total_clients': clientsSnap.docs.length,
      });
      // Clear history and reset user points in a single batch
      final historySnap = await historyCol.where('month', isEqualTo: curMonth).get();
      final batch = db.batch();
      
      for (final doc in historySnap.docs) { 
        batch.delete(doc.reference); 
      }
      for (final doc in usersSnap.docs) { 
        batch.update(doc.reference, {'points': 0}); 
      }
      
      await batch.commit();
      await logEvent(type: 'MONTH_ARCHIVED', description: 'Month $curMonth archived & reset');
      if (mounted) showSystemNotification(context, 'FINANCIAL PERIOD EXPORTED & ARCHIVED. POINTS RESET.');
    } catch (e) {
      if (mounted) showSystemNotification(context, 'ARCHIVE CORRUPTED: $e', isError: true);
    }
  }

  // ─── CSV Export ────────────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    try {
      final curMonth    = DateFormat('yyyy-MM').format(DateTime.now());
      final clientsSnap = await clientsCol.get();
      final usersSnap   = await usersCol.orderBy('points', descending: true).get();
      final expensesSnap= await expensesCol.where('month', isEqualTo: curMonth).get();

      double totalRevenue = 0, setupCosts = 0, teamExpenses = 0;
      for (final d in clientsSnap.docs) { totalRevenue += ((d.data() as Map)['amount_received'] as num? ?? 0).toDouble(); }
      for (final d in expensesSnap.docs) {
        final data = d.data();
        final amt = (data['amount'] as num? ?? 0).toDouble();
        if (data['type'] == 'setup_cost') {
          setupCosts += amt;
        } else {
          teamExpenses += amt;
        }
      }
      final netProfit = totalRevenue - setupCosts - teamExpenses;
      int totalPts = 0;
      for (final u in usersSnap.docs) { totalPts += ((u.data() as Map)['points'] as num? ?? 0).toInt(); }

      final rows = <List<dynamic>>[
        ['=== P&L SUMMARY - $curMonth ==='],
        ['Total Revenue', formatPKR(totalRevenue)],
        ['Setup Costs',   formatPKR(setupCosts)],
        ['Team Expenses', formatPKR(teamExpenses)],
        ['Net Profit',    formatPKR(netProfit)],
        [],
        ['=== TEAM PERFORMANCE ==='],
        ['Name', 'Points', '% Share', 'Payout (PKR)'],
        ...usersSnap.docs.map((u) {
          final data = u.data();
          final pts  = (data['points'] as num? ?? 0).toInt();
          final pct  = totalPts > 0 ? (pts / totalPts * 100) : 0.0;
          final pay  = calculatePayout(userPoints: pts, totalAgencyPoints: totalPts, netProfitPool: netProfit);
          return [data['name'] ?? u.id, pts, '${pct.toStringAsFixed(1)}%', formatPKR(pay)];
        }),
        [],
        ['=== CLIENT SUMMARY ==='],
        ['Client Name', 'Total Value', 'Received', 'Pending'],
        ...clientsSnap.docs.map((d) {
          final data = d.data();
          final total    = (data['total_project_value'] as num? ?? 0).toDouble();
          final received = (data['amount_received'] as num? ?? 0).toDouble();
          return [data['name'] ?? '-', formatPKR(total), formatPKR(received), formatPKR(total - received)];
        }),
      ];

      final csvLines = rows.map((row) => row.map((cell) {
        final s = cell.toString();
        return s.contains(',') || s.contains('\n') ? '"$s"' : s;
      }).join(',')).join('\n');
      final csv = csvLines;
      if (!mounted) return;
      showPulseModal(context, title: 'Export — $curMonth', child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: kBg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(csv, style: GoogleFonts.firaCode(fontSize: 10, color: kText.withValues(alpha: 0.7)))),
        ),
        const SizedBox(height: 24),
        Text('Select all text above and copy to paste into Excel/Sheets.', style: GoogleFonts.inter(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      ]));
    } catch (e) {
      if (mounted) showSystemNotification(context, 'DATA EXPORT FAILED: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          _sectionHeader('OPERATIONAL LOCK')
              .animate()
              .fadeIn(duration: 400.ms)
              .slideX(begin: -0.1, end: 0),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: kGlowDecoration(color: _monthLocked ? kError : kAccent, borderRadius: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [ 
                Icon(_monthLocked ? Icons.lock_rounded : Icons.lock_open_rounded, color: _monthLocked ? kError : kAccent, size: 20), 
                const SizedBox(width: 12), 
                Text('MONTH STATUS', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1)) 
              ]),
              const SizedBox(height: 12),
              Text('Locking the system prevents any new data entry points (tasks, expenses, attendance). Ensure all accounts are verified before activation.', 
                style: GoogleFonts.inter(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, height: 1.5, letterSpacing: 0.3)),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_monthLocked ? 'SYSTEM LOCKED' : 'SYSTEM ACTIVE', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: kText)),
                subtitle: Text(_monthLocked ? 'ALL WRITE ACCESS RESTRICTED' : 'STANDARD OPERATIONS PERMITTED', style: GoogleFonts.inter(fontSize: 9, color: kMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                value: _monthLocked,
                activeThumbColor: kError,
                activeTrackColor: kError.withValues(alpha: 0.2),
                onChanged: _toggleLock,
              ),
            ]),
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 48),
          _sectionHeader('WEIGHT CONFIGURATION')
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms)
              .slideX(begin: -0.1, end: 0),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: kGlowDecoration(color: kAccent, borderRadius: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit the relative reward points for each service vertical. Changes synchronize across all future verification events.', 
                style: GoogleFonts.inter(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, height: 1.5)),
              const SizedBox(height: 32),
              ..._weightCtrls.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                Expanded(child: Text(e.key.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1))),
                const SizedBox(width: 12),
                SizedBox(width: 100, child: TextField(
                  controller: e.value,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: kText, fontSize: 14, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true, fillColor: kBg.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kAccent.withValues(alpha: 0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kAccent.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kAccent, width: 2)),
                  ),
                )),
                const SizedBox(width: 12),
                Text('PTS', style: GoogleFonts.inter(color: kMuted, fontSize: 10, fontWeight: FontWeight.w900)),
              ]))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: kPrimaryButton(
                label: 'SYNCHRONIZE WEIGHTS',
                icon: Icons.sync_rounded,
                color: kGold,
                onPressed: _savingWeights ? null : _saveWeights,
              )),
            ]),
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 48),
          _sectionHeader('IDENTITY MANAGEMENT')
              .animate()
              .fadeIn(delay: 500.ms, duration: 400.ms)
              .slideX(begin: -0.1, end: 0),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: kGlowDecoration(color: kMuted, borderRadius: 28),
            child: StreamBuilder<QuerySnapshot>(
              stream: usersCol.snapshots(),
              builder: (_, snap) {
                final users = snap.data?.docs ?? [];
                if (users.isEmpty) return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('NO ENTITIES DETECTED', style: GoogleFonts.inter(color: kMuted, fontSize: 11, fontWeight: FontWeight.w900))));
                return Column(children: users.asMap().entries.map((e) {
                  final uDoc = e.value;
                  final u    = uDoc.data() as Map<String, dynamic>;
                  final name = u['name'] as String? ?? uDoc.id;
                  final role = u['role'] as String? ?? 'member';
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: kBg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: (role == 'admin' ? kGold : kAccent).withValues(alpha: 0.1), 
                        child: Text(name.substring(0, 1).toUpperCase(), style: TextStyle(color: role == 'admin' ? kGold : kAccent, fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                      title: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: kText)),
                      subtitle: Text('${(u['points'] as num? ?? 0)} ACCUMULATED PTS', style: GoogleFonts.inter(fontSize: 9, color: kMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      trailing: SizedBox(
                        width: 125,
                        child: AnimatedDashboardDropdown<String>(
                          value: role,
                          color: role == 'admin' ? kGold : kAccent,
                          items: const [
                            DropdownMenuItem(value: 'member', child: Text('MEMBER')),
                            DropdownMenuItem(value: 'admin',  child: Text('ADMIN')),
                          ],
                          onChanged: (newRole) async {
                            if (newRole == null) return;
                            await usersCol.doc(uDoc.id).update({'role': newRole});
                            if (mounted) showSystemNotification(context, '${name.toUpperCase()} GRANTED $newRole STATUS');
                          },
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: (600 + (e.key * 100)).ms, duration: 400.ms).slideX(begin: 0.05, end: 0);
                }).toList());
              },
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 48),
          _sectionHeader('SYSTEM ARCHIVE')
              .animate()
              .fadeIn(delay: 700.ms, duration: 400.ms)
              .slideX(begin: -0.1, end: 0),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: kGlowDecoration(color: kGold, borderRadius: 28),
            child: Column(children: [
              Text('Archiving executes a complete data snapshot and resets all dynamic activity logs for the current cycle.', 
                style: GoogleFonts.inter(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700, height: 1.5)),
              const SizedBox(height: 32),
              Row(children: [
                Expanded(child: kPrimaryButton(
                  label: 'ARCHIVE',
                  icon: Icons.archive_outlined,
                  color: kError,
                  onPressed: _archiveMonth,
                )),
                const SizedBox(width: 12),
                Expanded(child: kPrimaryButton(
                  label: 'EXPORT CSV',
                  icon: Icons.download_outlined,
                  color: kAccent,
                  onPressed: _exportCsv,
                )),
              ]),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16), 
                decoration: BoxDecoration(color: kBg.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: kAccent.withValues(alpha: 0.05))),
                child: Row(children: [
                   const Icon(Icons.info_outline_rounded, color: kAccent, size: 16),
                   const SizedBox(width: 12),
                   Expanded(child: Text('NOTE: Lifecycle maintenance requires daily cryptographic verification.', style: GoogleFonts.inter(color: kText.withValues(alpha: 0.2), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3))),
                ]),
              ),
            ]),
          ).animate().fadeIn(delay: 800.ms, duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 48),
        ],
      );
  }

  Widget _sectionHeader(String label) => Row(children: [
    Container(width: 4, height: 16, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 12),
    Text(label, style: GoogleFonts.syncopate(fontSize: 13, fontWeight: FontWeight.w900, color: kText, letterSpacing: 1.2)),
  ]);
}
