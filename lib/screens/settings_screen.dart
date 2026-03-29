import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
        final data = doc.data() as Map<String, dynamic>;
        data.forEach((k, v) {
          if (_weightCtrls.containsKey(k)) _weightCtrls[k]!.text = v.toString();
        });
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _loadLockStatus() async {
    try {
      final doc = await appConfigDoc.get();
      if (doc.exists) setState(() => _monthLocked = (doc.data() as Map<String, dynamic>?)?['month_locked'] == true);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Service weights saved!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { setState(() => _savingWeights = false); }
  }

  Future<void> _toggleLock(bool locked) async {
    await appConfigDoc.set({'month_locked': locked}, SetOptions(merge: true));
    await logEvent(type: locked ? 'MONTH_LOCKED' : 'MONTH_UNLOCKED', description: 'Month ${locked ? 'locked' : 'unlocked'} by admin');
    setState(() => _monthLocked = locked);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Month ${locked ? 'LOCKED 🔒' : 'UNLOCKED 🔓'}')));
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
        final data = d.data() as Map<String, dynamic>;
        final amt = (data['amount'] as num? ?? 0).toDouble();
        if (data['type'] == 'setup_cost') {
          setupCosts += amt;
        } else {
          teamExpenses += amt;
        }
      }
      final userSummaries = usersSnap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Month $curMonth archived & reset ✅')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive error: $e')));
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
        final data = d.data() as Map<String, dynamic>;
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
          final data = u.data() as Map<String, dynamic>;
          final pts  = (data['points'] as num? ?? 0).toInt();
          final pct  = totalPts > 0 ? (pts / totalPts * 100) : 0.0;
          final pay  = calculatePayout(userPoints: pts, totalAgencyPoints: totalPts, netProfitPool: netProfit);
          return [data['name'] ?? u.id, pts, '${pct.toStringAsFixed(1)}%', formatPKR(pay)];
        }),
        [],
        ['=== CLIENT SUMMARY ==='],
        ['Client Name', 'Total Value', 'Received', 'Pending'],
        ...clientsSnap.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final total    = (data['total_project_value'] as num? ?? 0).toDouble();
          final received = (data['amount_received'] as num? ?? 0).toDouble();
          return [data['name'] ?? '-', formatPKR(total), formatPKR(received), formatPKR(total - received)];
        }),
      ];

      // Generate CSV manually for reliable compatibility
      final csvLines = rows.map((row) => row.map((cell) {
        final s = cell.toString();
        return s.contains(',') || s.contains('\n') ? '"$s"' : s;
      }).join(',')).join('\n');
      final csv = csvLines;
      if (!mounted) return;
      showDialog(context: context, builder: (_) => Dialog(backgroundColor: kCard, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Text('Export — $curMonth', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ])),
        Container(constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70))))),
        Padding(padding: const EdgeInsets.all(16),
          child: Text('Select all text above and copy to paste into Excel/Sheets.', style: const TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center)),
      ])));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: kBg, title: Text('Admin Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white))),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // ═══ MONTH LOCK ═══
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ const Icon(Icons.lock_outline, color: kMuted), const SizedBox(width: 8), Text('Month Lock', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)) ]),
          const SizedBox(height: 4),
          const Text('Locking the month prevents any new writes (tasks, expenses, attendance). Do this before archiving.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          SwitchListTile(
            tileColor: kBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kBorder)),
            title: Text(_monthLocked ? '🔒 Month is LOCKED' : '🔓 Month is Open', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_monthLocked ? 'Writes are blocked' : 'Normal operations active', style: const TextStyle(fontSize: 12)),
            value: _monthLocked,
            activeThumbColor: Colors.redAccent,
            onChanged: _toggleLock,
          ),
        ]))),
        const SizedBox(height: 12),

        // ═══ SERVICE WEIGHTS ═══
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ const Icon(Icons.tune_rounded, color: kMuted), const SizedBox(width: 8), Text('Service Weight Config', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)) ]),
          const SizedBox(height: 4),
          const Text('Edit the point value for each service. Changes apply immediately to new task verifications.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          ..._weightCtrls.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Expanded(child: Text(e.key.replaceAll('_', ' '), style: const TextStyle(fontSize: 13, color: Colors.white70))),
            const SizedBox(width: 12),
            SizedBox(width: 80, child: TextField(
              controller: e.value,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true, fillColor: kBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent, width: 2)),
              ),
            )),
            const SizedBox(width: 4),
            const Text('pts', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            icon: _savingWeights ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Weights to Firestore'),
            style: FilledButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _savingWeights ? null : _saveWeights,
          )),
        ]))),
        const SizedBox(height: 12),

        // ═══ USER ROLE MANAGEMENT ═══
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ const Icon(Icons.manage_accounts_outlined, color: kMuted), const SizedBox(width: 8), Text('User Role Management', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)) ]),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: usersCol.snapshots(),
            builder: (_, snap) {
              final users = snap.data?.docs ?? [];
              if (users.isEmpty) return const Text('No users found.', style: TextStyle(color: Colors.white38));
              return Column(children: users.map((uDoc) {
                final u    = uDoc.data() as Map<String, dynamic>;
                final name = u['name'] as String? ?? uDoc.id;
                final role = u['role'] as String? ?? 'member';
                return Card(color: kBg, margin: const EdgeInsets.only(bottom: 6), child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: kAccent, radius: 16, child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${(u['points'] as num? ?? 0)} pts', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                    ])),
                    DropdownButton<String>(
                      value: role,
                      dropdownColor: kCard,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'member', child: Text('Member')),
                        DropdownMenuItem(value: 'admin',  child: Text('Admin')),
                      ],
                      onChanged: (newRole) async {
                        if (newRole == null) return;
                        await usersCol.doc(uDoc.id).update({'role': newRole});
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name set as $newRole')));
                      },
                    ),
                  ]),
                ));
              }).toList());
            },
          ),
        ]))),
        const SizedBox(height: 12),

        // ═══ ARCHIVE & EXPORT ═══
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [ const Icon(Icons.archive_outlined, color: kMuted), const SizedBox(width: 8), Text('Archive & Export', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)) ]),
          const SizedBox(height: 4),
          const Text('Archive saves a month snapshot to Firestore and clears the activity log.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Archive Month'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orangeAccent), foregroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _archiveMonth,
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export CSV'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.greenAccent), foregroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _exportCsv,
            )),
          ]),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.white38, size: 14),
              SizedBox(width: 6),
              Expanded(child: Text('Automated Day-8 pruning requires a Firebase Cloud Function. Use the Archive button for manual month close.', style: TextStyle(color: Colors.white38, fontSize: 11))),
            ])),
        ]))),
      ]),
    );
  }
}
