import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/local_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../match/match_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late String _aboutStatus;

  @override
  void initState() {
    super.initState();
    _aboutStatus = LocalStorage.instance.aboutStatus;
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter your name', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Your display name',
            hintStyle: TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryDark, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final u = authProvider.currentUser;
                await authProvider.updateProfile(
                  username: newName,
                  nativeLanguage: u.nativeLanguageName ?? 'English',
                  targetLanguage: u.targetLanguageName ?? 'Spanish',
                  proficiencyLevel: u.proficiencyLevel,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Display name updated to "$newName"'),
                      backgroundColor: AppColors.primaryDark,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditAboutDialog(BuildContext context) {
    final controller = TextEditingController(text: _aboutStatus);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('About / Status', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Add an about status',
            hintStyle: TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryDark, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newAbout = controller.text.trim();
              if (newAbout.isNotEmpty) {
                setState(() => _aboutStatus = newAbout);
                await LocalStorage.instance.setAboutStatus(newAbout);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Status updated successfully'),
                      backgroundColor: AppColors.primaryDark,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguagePickerDialog({
    required BuildContext context,
    required String title,
    required String currentLang,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: Colors.white10),
            ...kAvailableLanguages.map((lang) {
              final isSelected = lang == currentLang;
              return ListTile(
                leading: Icon(
                  Icons.language,
                  color: isSelected ? AppColors.primaryDark : AppColors.textSecondaryDark,
                ),
                title: Text(
                  lang,
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryDark : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryDark) : null,
                onTap: () {
                  onSelected(lang);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title changed to $lang'),
                      backgroundColor: AppColors.primaryDark,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;

        return Scaffold(
          backgroundColor: AppColors.backgroundDark,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceDark,
            title: const Text(
              'Profile',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            elevation: 0.5,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // 1. WhatsApp-Style Centered Large Avatar with Camera Icon Badge
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceDark,
                        border: Border.all(color: AppColors.primaryDark, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryDark,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Profile Details Section (WhatsApp Style)
              _buildSectionHeader('PROFILE INFORMATION'),
              _buildWhatsAppTile(
                icon: Icons.person_outline,
                title: 'Name',
                subtitle: user.username,
                footerText: 'This is visible to your practice partners.',
                trailingIcon: Icons.edit_outlined,
                onTap: () => _showEditNameDialog(context, user.username),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 64),
              _buildWhatsAppTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: _aboutStatus,
                trailingIcon: Icons.edit_outlined,
                onTap: () => _showEditAboutDialog(context),
              ),
              const Divider(color: Colors.white10, height: 1, indent: 64),
              _buildWhatsAppTile(
                icon: Icons.fingerprint,
                title: 'User ID',
                subtitle: user.userId,
                trailingIcon: Icons.copy,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: user.userId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User ID copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 3. Language Exchange Preferences
              _buildSectionHeader('LANGUAGE EXCHANGE PREFERENCES'),
              _buildWhatsAppTile(
                icon: Icons.record_voice_over,
                title: 'Native Language (I Speak)',
                subtitle: user.nativeLanguageName ?? 'English',
                trailingIcon: Icons.chevron_right,
                onTap: () {
                  _showLanguagePickerDialog(
                    context: context,
                    title: 'Select Native Language',
                    currentLang: user.nativeLanguageName ?? 'English',
                    onSelected: (newLang) async {
                      await authProvider.updateProfile(
                        username: user.username,
                        nativeLanguage: newLang,
                        targetLanguage: user.targetLanguageName ?? 'Spanish',
                        proficiencyLevel: user.proficiencyLevel,
                      );
                    },
                  );
                },
              ),
              const Divider(color: Colors.white10, height: 1, indent: 64),
              _buildWhatsAppTile(
                icon: Icons.translate,
                title: 'Target Language (Learning)',
                subtitle: user.targetLanguageName ?? 'Spanish',
                trailingIcon: Icons.chevron_right,
                onTap: () {
                  _showLanguagePickerDialog(
                    context: context,
                    title: 'Select Learning Language',
                    currentLang: user.targetLanguageName ?? 'Spanish',
                    onSelected: (newLang) async {
                      await authProvider.updateProfile(
                        username: user.username,
                        nativeLanguage: user.nativeLanguageName ?? 'English',
                        targetLanguage: newLang,
                        proficiencyLevel: user.proficiencyLevel,
                      );
                    },
                  );
                },
              ),
              const Divider(color: Colors.white10, height: 1, indent: 64),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed, color: AppColors.primaryDark, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Proficiency Level',
                                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                              ),
                              Text(
                                'Level ${user.proficiencyLevel} of 5 (${_getProficiencyLabel(user.proficiencyLevel)})',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: user.proficiencyLevel.toDouble().clamp(1.0, 5.0),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: AppColors.primaryDark,
                      inactiveColor: Colors.white24,
                      onChanged: (val) async {
                        await authProvider.updateProfile(
                          username: user.username,
                          nativeLanguage: user.nativeLanguageName ?? 'English',
                          targetLanguage: user.targetLanguageName ?? 'Spanish',
                          proficiencyLevel: val.toInt(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. My Vocabulary Book
              _buildSectionHeader('MY VOCABULARY BOOK'),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: DatabaseHelper.instance.vocabularyNotifier,
                builder: (context, vocabList, _) {
                  if (vocabList.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bookmark_outline, color: AppColors.primaryLight, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No vocabulary saved yet.\nTap on words in chat messages to bookmark them!',
                                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vocabList.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 64),
                    itemBuilder: (ctx, idx) {
                      final item = vocabList[idx];
                      final word = item['word'] ?? '';
                      final lang = item['language'] ?? 'Language';
                      final contextStr = item['context'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryDark.withValues(alpha: 0.2),
                          child: const Icon(Icons.bookmark, color: AppColors.primaryLight, size: 18),
                        ),
                        title: Text(
                          word,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          '$lang • "$contextStr"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                          onPressed: () async {
                            await DatabaseHelper.instance.deleteVocabularyAtIndex(idx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed "$word" from vocabulary book'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),

              // 5. App Theme & Preferences
              _buildSectionHeader('APP SETTINGS'),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return ListTile(
                    leading: const Icon(Icons.dark_mode_outlined, color: AppColors.primaryDark),
                    title: const Text('Dark Theme', style: TextStyle(color: Colors.white, fontSize: 15)),
                    subtitle: const Text('WhatsApp dark wallpaper theme', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      activeThumbColor: AppColors.primaryDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 5. Account Actions (Log Out / Switch Account)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF5350),
                      side: const BorderSide(color: Color(0xFFEF5350), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Log Out / Switch Account', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 6. WhatsApp Security Footer
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondaryDark),
                    SizedBox(width: 6),
                    Text(
                      'End-to-end encrypted WebRTC practice exchange',
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _getProficiencyLabel(int level) {
    switch (level) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Elementary';
      case 3:
        return 'Intermediate';
      case 4:
        return 'Upper Intermediate';
      case 5:
        return 'Fluent / Native';
      default:
        return 'Intermediate';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildWhatsAppTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? footerText,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (footerText != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      footerText,
                      style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, color: AppColors.primaryDark, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
