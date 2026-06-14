import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  // Passwort-Anforderungen dynamisch berechnen
  bool get _hasLength => _newCtrl.text.length >= 8;
  bool get _hasUppercase => _newCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumberOrSpecial => _newCtrl.text.contains(RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>_\-]'));

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Bitte alle Felder ausfüllen.');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = 'Passwörter stimmen nicht überein.');
      return;
    }
    if (!_hasLength) {
      setState(() => _error = 'Das Passwort muss mindestens 8 Zeichen lang sein.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await context.read<AuthProvider>().changePassword(current, newPw);
      if (mounted) _showSuccessSheet();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSheet() {
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
                shape: BoxShape.circle),
            child: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          Text('Passwort geändert!',
              style: GoogleFonts.lexend(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('Dein Passwort wurde erfolgreich aktualisiert.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Fertig', style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // ── AppBar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: AppColors.background,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(child: Text('Passwort ändern',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w700))),
            const SizedBox(width: 48),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Passwort ändern',
                style: GoogleFonts.lexend(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Dein neues Passwort muss mindestens 8 Zeichen lang sein und sich vom bisherigen unterscheiden.',
                style: GoogleFonts.lexend(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 28),
            _buildLabel('Aktuelles Passwort'),
            const SizedBox(height: 8),
            _buildPasswordField(_currentCtrl, 'Passwort eingeben', _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent)),
            const SizedBox(height: 20),
            _buildLabel('Neues Passwort'),
            const SizedBox(height: 8),
            _buildPasswordField(_newCtrl, 'Mindestens 8 Zeichen', _obscureNew,
                () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 20),
            _buildLabel('Passwort bestätigen'),
            const SizedBox(height: 8),
            _buildPasswordField(_confirmCtrl, 'Passwort wiederholen', _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 20),
            // Sicherheitsanforderungen
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SICHERHEITSANFORDERUNGEN',
                    style: GoogleFonts.lexend(fontSize: 9, color: AppColors.textMuted,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                _buildReq(_hasLength, 'Mindestens 8 Zeichen'),
                const SizedBox(height: 8),
                _buildReq(_hasUppercase, 'Ein Großbuchstabe'),
                const SizedBox(height: 8),
                _buildReq(_hasNumberOrSpecial, 'Eine Zahl oder ein Sonderzeichen'),
              ]),
            ),
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
                  backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8, shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                    : Text('Passwort speichern',
                        style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
                ),
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

  Widget _buildPasswordField(TextEditingController ctrl, String hint,
      bool obscure, VoidCallback toggle) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
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
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.primary.withValues(alpha: 0.7)),
            onPressed: toggle,
          ),
        ),
      );

  Widget _buildReq(bool met, String label) => Row(children: [
    Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 16, color: met ? AppColors.primary : AppColors.textMuted),
    const SizedBox(width: 10),
    Text(label,
        style: GoogleFonts.lexend(fontSize: 13,
            color: met ? Colors.white : AppColors.textSecondary)),
  ]);
}
