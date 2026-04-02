import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_constants.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _showScanner = false, _processing = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final scanned  = barcode!.rawValue!;
    final today    = DateTime.now().toIso8601String().substring(0, 10);
    final expected = 'agency_ops_attendance_$today';

    if (scanned != expected) {
      if (context.mounted) showSystemNotification(context, 'INVALID OR EXPIRED BIOMETRIC SIGNATURE', isError: true);
      setState(() => _showScanner = false);
      return;
    }
    setState(() => _processing = true);
    try {
      if (await isMonthLocked()) {
        if (context.mounted) showSystemNotification(context, 'SECURITY LOCK: MONTH IS DEACTIVATED', isError: true);
        setState(() => _showScanner = false);
        return;
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await usersCol.doc(uid).set({
        'points': FieldValue.increment(attendancePoints),
        'last_attendance': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await logEvent(type: 'ATTENDANCE', description: 'QR attendance scanned (+$attendancePoints pts)');
      if (context.mounted) showSystemNotification(context, 'BIOMETRIC SIGNATURE VERIFIED. +$attendancePoints POINTS', isError: false);
      setState(() => _showScanner = false);
    } catch (e) {
      if (context.mounted) showSystemNotification(context, 'SYSTEM ERROR: $e', isError: true);
      setState(() => _showScanner = false);
    } finally { setState(() => _processing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final today        = DateTime.now().toIso8601String().substring(0, 10);
    final secureQrData = 'agency_ops_attendance_$today';

    return StreamBuilder<DocumentSnapshot>(
      stream: usersCol.doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final bool isAdmin = (userData?['role'] == 'admin') || (FirebaseAuth.instance.currentUser?.uid == kSuperAdminUID);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [
            // ── TOP IDENTITY ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: kGlowDecoration(color: kAccent, borderRadius: 32),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: kBg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                     child: Icon(isAdmin ? Icons.cloud_done : Icons.qr_code_scanner_rounded, color: kAccent, size: 28),
                   ),
                   const SizedBox(width: 20),
                   Expanded(
                     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                       Text(isAdmin ? 'VERIFIER HUB' : 'ENTRY TERMINAL', 
                         style: GoogleFonts.syncopate(fontSize: 16, fontWeight: FontWeight.w900, color: kText, letterSpacing: -1)),
                       Text('SECURE BIOMETRIC SYNC', 
                         style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: kMuted, letterSpacing: 2)),
                     ]),
                   ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 32),
            
            Text(
              isAdmin 
                ? 'Display this unique daily cryptographic signature to verify member presence and authorize profit-pool allocation.'
                : 'Synchronize your unique biometric signature with the administrative hub to validate daily operations participation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: kMuted.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w700, height: 1.8, letterSpacing: 0.2),
            ),
            const SizedBox(height: 40),
            
            // ── Admin QR Section ──
            if (isAdmin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: kBentoDecoration(),
                child: Column(children: [
                   Text('SYSTEM VERIFIER', style: GoogleFonts.syncopate(letterSpacing: 3, fontWeight: FontWeight.w900, color: kGold, fontSize: 11)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: -10)],
                    ),
                    child: QrImageView(
                      data: secureQrData, 
                      version: QrVersions.auto, 
                      size: 200.0, 
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(DateFormat('EEEE, dd MMM').format(DateTime.now()).toUpperCase(), 
                    style: GoogleFonts.syncopate(letterSpacing: 1, fontWeight: FontWeight.w900, color: kText, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: kBg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
                    child: Text('ADMINISTRATIVE AUTHENTICATION ONLY', style: GoogleFonts.inter(color: kMuted, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1)),
                  ),
                ]).animate().fadeIn(delay: 200.ms, duration: 600.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
              ),
            
            if (isAdmin) const SizedBox(height: 48),

            if (!isAdmin) ...[
              if (!_showScanner) 
                SizedBox(width: double.infinity, child: kPrimaryButton(
                  label: 'INITIALIZE SCANNER',
                  icon: Icons.camera_alt_rounded,
                  color: kAccent,
                  onPressed: () => setState(() { _showScanner = true; }),
                ))
              else ...[
                Stack(alignment: Alignment.center, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 350, 
                      decoration: BoxDecoration(border: Border.all(color: kAccent.withValues(alpha: 0.3), width: 2)),
                      child: MobileScanner(controller: _ctrl, onDetect: _onDetect),
                    )),
                  // Scanner Frame Overlay
                  _scannerOverlay(),
                  if (_processing) const CircularProgressIndicator(color: kAccent, strokeWidth: 4),
                ]),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => setState(() => _showScanner = false), 
                  icon: const Icon(Icons.close_rounded, size: 18), 
                  label: Text('ABORT FIELD SCAN', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)), 
                  style: TextButton.styleFrom(foregroundColor: kError.withValues(alpha: 0.6)),
                ),
              ],
            ],
            
            const SizedBox(height: 48),
            _infoPanel(),
            const SizedBox(height: 32),
          ]),
        );
      },
    );
  }

  Widget _scannerOverlay() => Container(
    width: 200, height: 200,
    decoration: BoxDecoration(
      border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 1.5),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Stack(children: [
       Align(
         alignment: Alignment.topCenter, 
         child: Container(
           width: 180, height: 2, 
           decoration: BoxDecoration(color: kAccent, boxShadow: [BoxShadow(color: kAccent, blurRadius: 20, spreadRadius: 4)]),
         ),
       ),
    ]),
  );

  Widget _infoPanel() => Container(
    width: double.infinity, padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: kCard.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24), border: Border.all(color: kBorder.withValues(alpha: 0.05))),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.stars_rounded, color: kGold, size: 28),
      ),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DAILY REWARD POOL', style: GoogleFonts.syncopate(color: kText, fontWeight: FontWeight.w900, fontSize: 11)),
        const SizedBox(height: 6),
        Text('Verify your presence to earn $attendancePoints PTS towards your monthly profit share.', 
          style: GoogleFonts.inter(color: kMuted.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w800, height: 1.5)),
      ])),
    ]),
  );
}
