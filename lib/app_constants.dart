import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─── Firestore Collection References ───────────────────────────────────────
final FirebaseFirestore db = FirebaseFirestore.instance;
// ignore: non_constant_identifier_names
CollectionReference get clientsCol  => db.collection('clients');
CollectionReference get tasksCol    => db.collection('tasks');
CollectionReference get usersCol    => db.collection('users');
CollectionReference get expensesCol => db.collection('expenses');
CollectionReference get historyCol  => db.collection('history');
DocumentReference  get appConfigDoc      => db.collection('config').doc('app_config');
DocumentReference  get serviceWeightsDoc => db.collection('config').doc('service_weights');

// ─── Constants ─────────────────────────────────────────────────────────────
const Map<String, int> defaultServiceWeights = {
  'MOBILE_APP': 100, 'WEB_APP': 90,   'UI_UX': 60,    'GRAPHICS': 40,
  'VIDEO_EDIT': 50,  'STUDIO': 60,    'MODELING': 30,  'ACADEMIC': 40,
  'ADS_CAMPAIGN': 70,'SOCIAL_MEDIA': 30,'CONTENT_WRITING': 25,'INTERNAL_OPS': 15,
};
Map<String, int> serviceWeights = Map.from(defaultServiceWeights);
const int attendancePoints = 10;
const int urgentBonus = 25;

// ─── Payout Engine ──────────────────────────────────────────────────────────
double calculatePayout({
  required int userPoints,
  required int totalAgencyPoints,
  required double netProfitPool,
}) {
  if (totalAgencyPoints == 0 || netProfitPool <= 0) return 0.0;
  return (userPoints / totalAgencyPoints) * netProfitPool;
}

// ─── History Logger ─────────────────────────────────────────────────────────
Future<void> logEvent({
  required String type,
  required String description,
  String? clientId,
  String? taskId,
  double? amount,
}) async {
  try {
    await historyCol.add({
      'type': type,
      'description': description,
      'client_id': clientId,
      'task_id':   taskId,
      'amount':    amount,
      'actor_uid': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'month': DateFormat('yyyy-MM').format(DateTime.now()),
    });
  } catch (e) { debugPrint('logEvent error: $e'); }
}

// ─── Month Lock ──────────────────────────────────────────────────────────────
Future<bool> isMonthLocked() async {
  try {
    final doc = await appConfigDoc.get();
    if (!doc.exists) return false;
    return (doc.data() as Map<String, dynamic>?)?['month_locked'] == true;
  } catch (_) { return false; }
}

// ─── Service Weights from Firestore ─────────────────────────────────────────
Future<void> refreshServiceWeights() async {
  try {
    final doc = await serviceWeightsDoc.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      serviceWeights = data.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
  } catch (_) {}
}

// ─── Deadline Helpers ────────────────────────────────────────────────────────
int parseAllocatedDays(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  final lower = raw.toLowerCase();
  final m = RegExp(r'(\d+)').firstMatch(lower);
  if (m == null) return 0;
  final n = int.tryParse(m.group(1) ?? '0') ?? 0;
  if (lower.contains('week')) return n * 7;
  if (lower.contains('hour')) return 0;
  return n;
}

DateTime? computeDeadline(Map<String, dynamic> task) {
  final ts = task['created_at'];
  if (ts == null) return null;
  final created = (ts as Timestamp).toDate();
  final days = parseAllocatedDays(task['allocated_time'] as String?);
  if (days == 0) return null;
  return created.add(Duration(days: days));
}

String formatTimeRemaining(DateTime? deadline) {
  if (deadline == null) return '';
  final diff = deadline.difference(DateTime.now());
  if (diff.isNegative) return 'OVERDUE';
  if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h left';
  if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
  return '${diff.inMinutes}m left';
}

String formatPKR(double v) => 'PKR ${NumberFormat('#,##0').format(v)}';

// ─── Shared UI Widgets ───────────────────────────────────────────────────────
const Color kBg    = Color(0xFF0F0F1A);
const Color kCard  = Color(0xFF1C1C2E);
const Color kBorder= Color(0xFF2A2A3E);
const Color kAccent= Color(0xFF4F46E5);
const Color kMuted = Color(0xFF818CF8);

InputDecoration kInputDecoration(String label, IconData icon) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, color: kMuted),
  filled: true, fillColor: kBg,
  labelStyle: const TextStyle(color: Colors.white54),
  border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAccent, width: 2)),
);

Widget kSectionTitle(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
);

Widget statusBadge(String status) {
  final Color c;
  switch (status) {
    case 'VERIFIED':             c = Colors.greenAccent; break;
    case 'PENDING_VERIFICATION': c = Colors.orangeAccent; break;
    default:                     c = kMuted;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withValues(alpha: 0.4)),
    ),
    child: Text(status.replaceAll('_', ' '), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

FilledButton kPrimaryButton({required String label, required VoidCallback? onPressed, IconData? icon}) =>
  FilledButton.icon(
    icon: Icon(icon ?? Icons.check, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: kAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    onPressed: onPressed,
  );
