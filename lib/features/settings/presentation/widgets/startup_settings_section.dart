import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../services/app_settings_service.dart';

class StartupSettingsSection extends StatefulWidget {
  const StartupSettingsSection({super.key});
  @override
  State<StartupSettingsSection> createState() => _StartupSettingsSectionState();
}
class _StartupSettingsSectionState extends State<StartupSettingsSection> {
  late bool _enabled = AppSettingsService.splashEnabled;
  late double _duration = AppSettingsService.splashDurationMs / 1000;
  late String _style = AppSettingsService.splashStyle;
  late final _title = TextEditingController(text: AppSettingsService.splashTitle);
  late final _subtitle = TextEditingController(text: AppSettingsService.splashSubtitle);
  bool _saving = false;
  @override
  void dispose() { _title.dispose(); _subtitle.dispose(); super.dispose(); }
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppSettingsService.saveSplashSettings(enabled: _enabled,
        durationMs: (_duration * 1000).round(), style: _style,
        title: _title.text.trim(), subtitle: _subtitle.text.trim());
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Saved')))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Unable to save settings')))); }
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.tr('Show startup screen')),
        value: _enabled, onChanged: _saving ? null : (value) => setState(() => _enabled = value)),
      if (_enabled) ...[
        Text('${context.tr('Display duration')}: ${_duration.toStringAsFixed(1)} ${context.tr('seconds')}'),
        Slider(value: _duration, min: .2, max: 3, divisions: 28,
          onChanged: _saving ? null : (value) => setState(() => _duration = value)),
        DropdownButtonFormField<String>(initialValue: _style,
          decoration: InputDecoration(labelText: context.tr('Style')),
          items: [DropdownMenuItem(value: 'minimal', child: Text(context.tr('Minimal'))),
            DropdownMenuItem(value: 'decorated', child: Text(context.tr('Animated logo')))],
          onChanged: _saving ? null : (value) { if (value != null) setState(() => _style = value); }),
        const SizedBox(height: 12),
        TextField(controller: _title, maxLength: 40, decoration: InputDecoration(labelText: context.tr('Startup title'))),
        TextField(controller: _subtitle, maxLength: 100, decoration: InputDecoration(labelText: context.tr('Startup subtitle'))),
      ],
      const SizedBox(height: 8),
      Text(context.tr('Android may still show its system launch screen briefly.')),
      const SizedBox(height: 12),
      FilledButton(onPressed: _saving ? null : _save, child: Text(context.tr('Save'))),
    ]));
}
