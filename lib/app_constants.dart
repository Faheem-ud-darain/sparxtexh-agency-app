import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

// ── COLOR SYSTEM ────────────────────────────────────────────────────────────
const kBg      = Color(0xFF030303); // Deep Obsidian
const kCard    = Color(0xFF0C0C0C); // Dark Onyx
const kAccent  = Color(0xFFA78BFA); // Electric Lavender
const kGold    = Color(0xFFFACC15); // Golden Aura
const kMuted   = Color(0xFF94A3B8); // Slate Dust
const kText    = Color(0xFFF8FAFC); // Cloud White
const kBorder  = Color(0xFF1E293B); // Midnight Stroke
const kError   = Color(0xFFEF4444); // Crimson Alert
const kSuccess = Color(0xFF22C55E); // Emerald Success

const kSuperAdminUID = 'fIAsD7pYqSTp6M9Rz5U8T6T8U8T6';
const urgentBonus = 25;
const attendancePoints = 10;

final db = FirebaseFirestore.instance;
final usersCol    = db.collection('users');
final clientsCol  = db.collection('clients');
final tasksCol    = db.collection('tasks');
final expensesCol = db.collection('expenses');
final historyCol  = db.collection('history');
final notificationsCol = db.collection('notifications');
final paymentsCol = db.collection('payments');
final appConfigDoc= db.collection('config').doc('app_config');
final serviceWeightsDoc = db.collection('config').doc('service_weights');

// Initial defaults
Map<String, int> defaultServiceWeights = {
  'web_dev': 100,
  'graphic_design': 40,
  'digital_marketing': 60,
  'video_editing': 80,
  'content_writing': 30,
  'mobile_app': 120,
};

Map<String, int> serviceWeights = Map.from(defaultServiceWeights);

Future<void> refreshServiceWeights() async {
  final snap = await serviceWeightsDoc.get();
  if (snap.exists) {
    serviceWeights = Map<String, int>.from(snap.data()!);
  }
}

Future<bool> isMonthLocked() async {
  final snap = await appConfigDoc.get();
  return snap.exists && (snap.data()?['isLocked'] ?? false);
}

InputDecoration kInputDecoration(String label, IconData icon) => InputDecoration(
  labelText: label,
  labelStyle: GoogleFonts.inter(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
  prefixIcon: Icon(icon, color: kAccent, size: 20),
  filled: true,
  fillColor: kCard,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kBorder, width: 1.5)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kBorder, width: 1.5)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: kAccent, width: 2)),
  errorStyle: GoogleFonts.inter(color: kError, fontSize: 10),
  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
);

BoxDecoration kBentoDecoration({Color? color, double opacity = 0.05}) => BoxDecoration(
  color: kCard,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: (color ?? kAccent).withValues(alpha: 0.15), width: 1.5),
  boxShadow: [
    BoxShadow(color: (color ?? kAccent).withValues(alpha: opacity), blurRadius: 40, spreadRadius: -10),
  ],
);

Widget kSectionTitle(String title, {IconData? icon}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Row(
    children: [
      if (icon != null) ...[Icon(icon, color: kGold, size: 16), const SizedBox(width: 10)],
      Text(title, style: GoogleFonts.syncopate(fontSize: 12, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 2)),
      const SizedBox(width: 15),
      Expanded(child: Divider(color: kBorder, thickness: 1)),
    ],
  ),
);

BoxDecoration kGlowDecoration({required Color color, double borderRadius = 24}) => BoxDecoration(
  color: kCard,
  borderRadius: BorderRadius.circular(borderRadius),
  border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
  boxShadow: [
    BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 40, spreadRadius: -10),
  ],
);

Widget kPrimaryButton({required String label, required VoidCallback? onPressed, IconData? icon, Color color = kAccent}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: color.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: 10)],
        Flexible(child: Text(label, style: GoogleFonts.syncopate(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5), overflow: TextOverflow.ellipsis)),
      ],
    ),
  ).animate(onPlay: (ctrl) => ctrl.repeat(reverse: true)).shimmer(duration: 3.seconds, color: color.withValues(alpha: 0.1));
}

void showPulseModal(BuildContext context, {required String title, required Widget child}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black87,
    builder: (ctx) => Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: kBorder, width: 2),
        boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.1), blurRadius: 50, spreadRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 5, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Row(children: [
              Text(title, style: GoogleFonts.syncopate(fontSize: 14, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 1)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: kMuted)),
            ]),
          ),
          const Divider(color: kBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
  );
}

String formatPKR(double amount) => 'PKR ${NumberFormat("#,##,###").format(amount)}';

double calculatePayout({required int userPoints, required int totalAgencyPoints, required double netProfitPool}) {
  if (totalAgencyPoints <= 0) return 0;
  return (userPoints / totalAgencyPoints) * netProfitPool;
}

Future<void> logEvent({required String type, required String description, String? taskId, String? clientId, double? amount}) async {
  try {
    await historyCol.add({
      'type': type,
      'description': description,
      'taskId': taskId,
      'clientId': clientId,
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
      'month': DateFormat('yyyy-MM').format(DateTime.now()),
    });
  } catch (_) {}
}

void showSystemNotification(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.warning_amber_rounded : Icons.auto_awesome, color: isError ? kError : kAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: GoogleFonts.inter(color: kText, fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
      backgroundColor: kBg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isError ? kError.withValues(alpha: 0.3) : kAccent.withValues(alpha: 0.3)),
      ),
      margin: const EdgeInsets.all(16),
      elevation: 0,
      duration: const Duration(seconds: 4),
    ),
  );
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────
class PulseGlow extends StatelessWidget {
  final Widget child;
  final Color color;
  const PulseGlow({super.key, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return child.animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
        .boxShadow(begin: const BoxShadow(blurRadius: 0, spreadRadius: 0, color: Colors.transparent),
                  end: BoxShadow(blurRadius: 20, spreadRadius: 2, color: color.withValues(alpha: 0.1)));
  }
}

// ── CUSTOM ANIMATED DROPDOWN ────────────────────────────────────────────────
class AnimatedDashboardDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final Color? color;
  final bool isExpanded;

  const AnimatedDashboardDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.color,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (color ?? kAccent).withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: (color ?? kAccent).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: kCard,
          icon: Icon(Icons.expand_more_rounded, color: color ?? kAccent, size: 20),
          style: GoogleFonts.inter(color: kText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          borderRadius: BorderRadius.circular(20),
          elevation: 16,
          menuMaxHeight: 400,
          isExpanded: isExpanded,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }
}

class DashboardDropDownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color? color;

  const DashboardDropDownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color ?? kAccent),
              const SizedBox(width: 8),
              Text(label.toUpperCase(), style: GoogleFonts.syncopate(fontSize: 10, fontWeight: FontWeight.w900, color: color ?? kAccent, letterSpacing: 1.5)),
            ],
          ),
        ),
        AnimatedDashboardDropdown<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          color: color,
        ),
      ],
    );
  }
}
