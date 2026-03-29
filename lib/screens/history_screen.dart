import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../app_constants.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: historyCol.orderBy('timestamp', descending: true).limit(50).snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('Empty history.', style: TextStyle(color: Colors.white30)));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          itemCount: docs.length,
          itemBuilder: (ctx, idx) {
            final d = docs[idx].data() as Map<String, dynamic>;
            final ts = d['timestamp'] as Timestamp?;
            final time = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '--:--';
            final date = ts != null ? DateFormat('dd MMM').format(ts.toDate()) : '';
            final type = d['type'] as String? ?? 'LOG';
            final isFirstOfDay = idx == 0 || (docs[idx-1].data() as Map)['timestamp']?.toDate()?.day != ts?.toDate()?.day;

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isFirstOfDay) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Text(date.toUpperCase(), style: GoogleFonts.inter(letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w900, color: kMuted)),
                ),
              ],
              IntrinsicHeight(
                child: Row(children: [
                   Column(children: [
                    Container(width: 2, height: 16, color: idx == 0 && isFirstOfDay ? Colors.transparent : kBorder),
                    _timelineIcon(type),
                    Expanded(child: Container(width: 2, color: idx == docs.length - 1 ? Colors.transparent : kBorder)),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                         Row(children: [
                           Expanded(child: Text(d['description'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white))),
                           Text(time, style: const TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.w600)),
                         ]),
                         if (d['amount'] != null) ...[
                            const SizedBox(height: 8),
                            Text(formatPKR(d['amount']), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 13)),
                         ],
                      ]),
                    ),
                  )),
                ]),
              ),
            ]);
          },
        );
      },
    );
  }

  Widget _timelineIcon(String type) {
    IconData icon = Icons.info_outline;
    Color color = Colors.blueAccent;
    switch(type) {
      case 'ATTENDANCE': icon = Icons.check_circle; color = Colors.greenAccent; break;
      case 'TASK_SUBMITTED': icon = Icons.upload_file; color = Colors.orangeAccent; break;
      case 'TASK_VERIFIED': icon = Icons.verified; color = Colors.tealAccent; break;
      case 'EXPENSE_ADDED': icon = Icons.remove_circle; color = Colors.redAccent; break;
      case 'CLIENT_ADDED': icon = Icons.person_add; color = Colors.purpleAccent; break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
