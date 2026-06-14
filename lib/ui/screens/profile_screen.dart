import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingImage = false;
  bool _isUploadingCatalog = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      final profile = await FirestoreService().getUserProfile(user.uid);
      if (profile != null && profile['isAdmin'] == true) {
        if (mounted) {
          setState(() {
            _isAdmin = true;
          });
        }
      }
    }
  }

  Future<void> _uploadCatalog() async {
    setState(() => _isUploadingCatalog = true);
    try {
      final String response = await rootBundle.loadString('assets/woerter.json');
      final Map<String, dynamic> data = json.decode(response);

      List<Map<String, dynamic>> itemsToUpload = [];

      data.forEach((term, translations) {
        if (translations is Map<String, dynamic>) {
          if (translations.containsKey('en')) {
            itemsToUpload.add({
              'term': term,
              'translation': translations['en'],
              'language': 'en',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          if (translations.containsKey('es')) {
            itemsToUpload.add({
              'term': term,
              'translation': translations['es'],
              'language': 'es',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      if (itemsToUpload.isNotEmpty) {
        await FirestoreService().uploadGlobalCatalog(itemsToUpload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${itemsToUpload.length} Wörter erfolgreich hochgeladen!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      print('DEBUG: Catalog Upload Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Hochladen: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCatalog = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      // Bild als Base64 enkodieren und als Data-URI speichern
      final bytes = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Str';

      // Nur in Firestore speichern (kein Firebase Storage nötig)
      await context.read<FirestoreService>().saveUserProfile(uid, {'photoUrl': dataUri});
      auth.updatePhotoUrlLocalOnly(dataUri);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profilbild erfolgreich aktualisiert!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profilbild ändern',
                  style: GoogleFonts.lexend(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _sourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Aus Galerie wählen',
                source: ImageSource.gallery,
                ctx: ctx,
              ),
              const SizedBox(height: 12),
              _sourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Foto aufnehmen',
                source: ImageSource.camera,
                ctx: ctx,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption({
    required IconData icon,
    required String label,
    required ImageSource source,
    required BuildContext ctx,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: GoogleFonts.lexend(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }


  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Abmelden',
            style: GoogleFonts.lexend(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Möchtest du dich wirklich abmelden?',
            style: GoogleFonts.lexend(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen',
                style: GoogleFonts.lexend(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Abmelden',
                style: GoogleFonts.lexend(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, VocabularyProvider>(
      builder: (context, auth, vocab, _) {
        final user = auth.currentUser;
        final displayName = user?.displayName ?? 'User';
        final email = user?.email ?? '';
        // Nutzt auth.photoUrl damit Base64-Override sofort sichtbar ist
        final photoUrl = auth.photoUrl;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── AppBar ──────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: AppColors.background,
                  pinned: true,
                  elevation: 0,
                  title: Text('Profil',
                      style: GoogleFonts.lexend(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  centerTitle: true,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                      tooltip: 'Einstellungen',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // ── Avatar ─────────────────────────────────────
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.accent
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: UserAvatar(
                                photoUrl: photoUrl,
                                displayName: displayName,
                                radius: 60,
                                fallbackBackground: Colors.transparent,
                              ),
                            ),
                            // Edit-Button
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isUploadingImage
                                    ? null
                                    : _pickAndUploadImage,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.background, width: 2),
                                  ),
                                  child: _isUploadingImage
                                      ? const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Icon(Icons.edit_rounded,
                                          size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Name & E-Mail ──────────────────────────────
                        Text(displayName,
                            style: GoogleFonts.lexend(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: GoogleFonts.lexend(
                                fontSize: 13,
                                color: AppColors.textSecondary)),

                        const SizedBox(height: 32),

                        // ── Statistiken ────────────────────────────────
                        _buildSectionTitle('Deine Statistiken'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.school_rounded,
                                iconColor: AppColors.primary,
                                label: 'GELERNTE WÖRTER',
                                value: '${vocab.mastered.length}',
                                sub: 'gesamt',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.local_fire_department_rounded,
                                iconColor: AppColors.accent,
                                label: 'AKTUELLER STREAK',
                                value: '0',
                                sub: 'Tage',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildWideStatCard(
                          icon: Icons.public_rounded,
                          iconColor: AppColors.success,
                          label: 'VOKABELN IN TRAINING',
                          value: '${vocab.training.length}',
                          sub: 'aktiv',
                        ),

                        const SizedBox(height: 40),

                        // ── Logout ─────────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded,
                                color: AppColors.danger),
                            label: Text('Abmelden',
                                style: GoogleFonts.lexend(
                                    color: AppColors.danger,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: AppColors.danger.withValues(alpha: 0.4)),
                              backgroundColor:
                                  AppColors.danger.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        if (_isAdmin) ...[
                          // ── Katalog Upload (Admin) ────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isUploadingCatalog ? null : _uploadCatalog,
                              icon: _isUploadingCatalog
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                              label: Text(
                                _isUploadingCatalog ? 'Lädt hoch...' : 'Katalog befüllen',
                                style: GoogleFonts.lexend(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 100),
                        ] else ...[
                          const SizedBox(height: 76),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title,
          style: GoogleFonts.lexend(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -4,
            right: -4,
            child: Icon(icon, size: 44, color: iconColor.withValues(alpha: 0.2)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.lexend(
                      fontSize: 9,
                      color: iconColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value,
                      style: GoogleFonts.lexend(
                          fontSize: 30,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text(sub,
                      style: GoogleFonts.lexend(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWideStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.lexend(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.lexend(
                      fontSize: 26,
                      color: iconColor,
                      fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' $sub',
                  style: GoogleFonts.lexend(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
