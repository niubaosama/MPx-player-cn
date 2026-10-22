import '../widgets/startup_settings_section.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:mpx/core/services/permission_service.dart';
import 'package:mpx/core/theme/app_theme_tokens.dart';
import 'package:mpx/features/downloader/presentation/screens/downloader_settings_screen.dart';
import 'package:mpx/features/downloader/presentation/screens/downloads_manager_screen.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_settings_controller.dart';
import '../../services/app_settings_service.dart';
import '../../services/subtitle_settings_service.dart';
import '../helpers/settings_helpers.dart';
import '../widgets/settings_header.dart';
import '../widgets/common_widgets.dart';
import '../widgets/form_rows.dart';
import '../widgets/expert_engine_settings_section.dart';
import '../widgets/subtitle_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Set<int> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settings = context.watch<AppSettingsController>();

    return Scaffold(
      backgroundColor: theme.appBackgroundAlt,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.appBackground, theme.appBackgroundAlt],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsHeader(),
                  const SizedBox(height: 16),
                  _buildExpandableSection(
                    index: 2,
                    title: context.tr('Language'),
                    icon: Icons.language,
                    colors: colors,
                    child: _LanguageSection(settings: settings),
                  ),
                  _buildExpandableSection(
                    index: 0,
                    title: context.tr('Appearance'),
                    icon: Icons.palette_outlined,
                    colors: colors,
                    child: _ThemeSection(settings: settings),
                  ),
                  _buildExpandableSection(
                    index: 1,
                    title: context.tr('Subtitles'),
                    icon: Icons.subtitles_outlined,
                    accent: const Color(0xFFEA580C),
                    colors: colors,
                    child: const _SubtitleSection(),
                  ),
                  _buildExpandableSection(
                    index: 3,
                    title: context.tr('Engine'),
                    icon: Icons.tune,
                    accent: const Color(0xFF0F766E),
                    colors: colors,
                    child: _EngineSection(settings: settings),
                  ),
                  _buildExpandableSection(
                    index: 4,
                    title: context.tr('Downloader'),
                    icon: Icons.download_rounded,
                    accent: const Color(0xFF2563EB),
                    colors: colors,
                    child: const _DownloaderSection(),
                  ),
                  if (Platform.isAndroid)
                    _buildExpandableSection(
                      index: 5,
                      title: context.tr('Storage & Permissions'),
                      icon: Icons.folder_outlined,
                      accent: const Color(0xFF7C3AED),
                      colors: colors,
                      child: const _StoragePermissionSection(),
                    ),
                  _buildExpandableSection(index: 6, title: context.tr('Startup screen'),
                    icon: Icons.rocket_launch_outlined, colors: colors,
                    child: const StartupSettingsSection()),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required int index,
    required String title,
    required IconData icon,
    required ColorScheme colors,
    Color? accent,
    required Widget child,
  }) {
    final isExpanded = _expandedSections.contains(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? (accent ?? colors.primary).withValues(alpha: 0.3)
                : colors.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(index);
                  } else {
                    _expandedSections.add(index);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (accent ?? colors.primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: accent ?? colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: isExpanded ? child : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Choose the app language. Changes take effect immediately.')),
          const SizedBox(height: 12),
          DropdownButton<AppLanguage>(
            value: settings.language,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: AppLanguage.system,
                child: Text(context.tr('Follow system')),
              ),
              const DropdownMenuItem(
                value: AppLanguage.zh,
                child: Text('简体中文'),
              ),
              const DropdownMenuItem(
                value: AppLanguage.en,
                child: Text('English'),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;
              final saved = await settings.setLanguage(value);
              if (!saved && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('Could not save language preference. Please try again.'))),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  final AppSettingsController settings;

  const _ThemeSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Pick light, dark, or follow device.'),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppThemePreference.values
                .map(
                  (preference) => SizedBox(
                    width: 150,
                    child: SettingsChoiceCard(
                      icon: SettingsThemeHelpers.getIcon(preference),
                      title: context.tr(SettingsThemeHelpers.getLabel(preference)),
                      subtitle: context.tr(SettingsThemeHelpers.getDescription(preference)),
                      isSelected: settings.themePreference == preference,
                      onTap: () => settings.setThemePreference(preference),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SubtitleSection extends StatelessWidget {
  const _SubtitleSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Applied to player automatically.'),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          SettingsSwitchRow(
            icon: Icons.subtitles_outlined,
            title: context.tr('Enable subtitles'),
            subtitle: context.tr('Keep captions on when available'),
            value: SubtitleSettingsService.isEnabled,
            onChanged: (value) async {
              await SubtitleSettingsService.setEnabled(value);
            },
          ),
          const SubtitleSettingsSection(),
        ],
      ),
    );
  }
}


class _EngineSection extends StatelessWidget {
  final AppSettingsController settings;

  const _EngineSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Decoder, sync, scaling, cache. Expert mode.'),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ExpertEngineSettingsSection(settings: settings),
        ],
      ),
    );
  }
}

class _DownloaderSection extends StatelessWidget {
  const _DownloaderSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Manage on-device downloads and downloader preferences.'),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_for_offline_outlined),
            title: Text(context.tr('Open downloader')),
            subtitle: Text(context.tr('Queue URLs and manage active downloads')),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadsManagerScreen(),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded),
            title: Text(context.tr('Downloader settings')),
            subtitle: Text(context.tr('Quality, cookies, updates, and diagnostics')),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DownloaderSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StoragePermissionSection extends StatefulWidget {
  const _StoragePermissionSection();

  @override
  State<_StoragePermissionSection> createState() =>
      _StoragePermissionSectionState();
}

class _StoragePermissionSectionState extends State<_StoragePermissionSection> {
  bool _hasFullAccess = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasAccess = await PermissionService.checkManageExternalStorage();
    setState(() {
      _hasFullAccess = hasAccess;
      _isLoading = false;
    });
  }

  Future<void> _requestFullAccess() async {
    setState(() => _isLoading = true);
    final granted = await PermissionService.requestManageExternalStorage();
    setState(() {
      _hasFullAccess = granted;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? context.tr('All files access granted. Restart the app if files still don\'t appear.')
                : context.tr('Permission not granted. Some features may be limited.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Control how MPx accesses files on your device. Required for full file browsing.'),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _hasFullAccess
                        ? Icons.check_circle
                        : Icons.folder_off_outlined,
                    color: _hasFullAccess ? Colors.green : null,
                  ),
                  title: Text(context.tr('All files access')),
                  subtitle: Text(
                    _hasFullAccess
                        ? context.tr('Granted - MPx can access all files')
                        : context.tr('Not granted - File browsing is limited. Tap to enable.'),
                  ),
                  trailing: _hasFullAccess
                      ? null
                      : TextButton(
                          onPressed: _requestFullAccess,
                          child: Text(context.tr('Enable')),
                        ),
                  onTap: _hasFullAccess ? null : _requestFullAccess,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('Samsung Secure Folder: Files inside Secure Folder are isolated. MPx can only access files within the same Secure Folder profile. To access main storage files, install MPx outside Secure Folder or copy files into Secure Folder.'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
