import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class ChangeMailScreen extends StatefulWidget {
  const ChangeMailScreen({super.key});

  @override
  State<ChangeMailScreen> createState() => _ChangeMailScreenState();
}

class _ChangeMailScreenState extends State<ChangeMailScreen> {
  final _newMailCtrl = TextEditingController();
  final _confirmMailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _newMailCtrl.dispose();
    _confirmMailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newMail = _newMailCtrl.text.trim();
    final confirmMail = _confirmMailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (newMail.isEmpty || confirmMail.isEmpty || password.isEmpty) {
      setState(() => _error = 'Bitte alle Felder ausfüllen.');
      return;
    }
    if (newMail != confirmMail) {
      setState(() => _error = 'E-Mail-Adressen stimmen nicht überein.');
      return;
    }
    if (!RegExp(r'^[\w\-.]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(newMail)) {
      setState(() => _error = 'Ungültige E-Mail-Adresse.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await context.read<AuthProvider>().changeEmail(newMail, password);
      if (mounted) {
        _showSuccessSheet(
          icon: Icons.mark_email_read_outlined,
          title: 'Bestätigungslink gesendet',
          message: 'Wir haben einen Bestätigungslink an\n$newMail gesendet.\nBitte klicke auf den Link, um die Änderung abzuschließen.',
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSheet({required IconData icon, required String title, required String message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.lexend(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: GoogleFonts.lexend(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Zurück', style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final currentEmail = context.read<AuthProvider>().currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // ── AppBar ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: AppColors.background,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(child: Text('E-Mail-Adresse ändern',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w700))),
            const SizedBox(width: 48),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Neue E-Mail festlegen',
                style: GoogleFonts.lexend(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // Aktuelle Mail
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aktuelle E-Mail-Adresse',
                    style: GoogleFonts.lexend(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(currentEmail,
                    style: GoogleFonts.lexend(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 28),
            _buildLabel('Neues Passwort zur Bestätigung'),
            const SizedBox(height: 8),
            _buildPasswordField(_passwordCtrl, 'Aktuelles Passwort eingeben'),
            const SizedBox(height: 20),
            _buildLabel('Neue E-Mail-Adresse'),
            const SizedBox(height: 8),
            _buildTextField(_newMailCtrl, 'neue-email@beispiel.de', TextInputType.emailAddress),
            const SizedBox(height: 20),
            _buildLabel('E-Mail-Adresse bestätigen'),
            const SizedBox(height: 8),
            _buildTextField(_confirmMailCtrl, 'neue-email@beispiel.de', TextInputType.emailAddress),
            const SizedBox(height: 16),
            // Info
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Wir senden dir einen Bestätigungslink an deine neue E-Mail-Adresse. Bitte klicke auf den Link, um die Änderung abzuschließen.',
                style: GoogleFonts.lexend(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
              )),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: GoogleFonts.lexend(fontSize: 13, color: AppColors.danger))),
                ]),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8, shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                    : Text('Speichern & Bestätigen',
                        style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Abbrechen',
                    style: GoogleFonts.lexend(color: AppColors.textSecondary, fontSize: 15)),
              ),
            ),
          ]),
        )),
      ])),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: GoogleFonts.lexend(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600));

  Widget _buildTextField(TextEditingController ctrl, String hint, TextInputType type) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: GoogleFonts.lexend(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.primary.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );

  Widget _buildPasswordField(TextEditingController ctrl, String hint) =>
      TextField(
        controller: ctrl,
        obscureText: _obscurePassword,
        style: GoogleFonts.lexend(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.primary.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.primary.withValues(alpha: 0.7)),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      );
}
