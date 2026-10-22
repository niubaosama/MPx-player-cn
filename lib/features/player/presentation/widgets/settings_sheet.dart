import 'package:flutter/material.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import 'package:mpx/core/theme/app_theme_tokens.dart';
import '../../controller/player_controller.dart';
import 'helpers/bottom_sheet_handle.dart';

class SettingsSheet extends StatelessWidget {
  final PlayerController controller;
  final VoidCallback? onOpenSubtitleSettings;

  const SettingsSheet({
    super.key,
    required this.controller,
    this.onOpenSubtitleSettings,
  });

  String _formatAspectRatio(BuildContext context, PlayerController controller) {
    return context.tr(controller.getAspectRatioLabel(controller.aspectRatioMode));
  }

  String _formatRepeatMode(BuildContext context, PlayerController controller) {
    return context.tr(controller.getRepeatModeLabel(controller.repeatMode));
  }

  String _formatAudioTrack(BuildContext context, PlayerController controller) {
    if (controller.audioTracks.isEmpty) return context.tr('Default');

    final safeIndex = controller.currentAudioTrackIndex < 0
        ? 0
        : controller.currentAudioTrackIndex >= controller.audioTracks.length
            ? controller.audioTracks.length - 1
            : controller.currentAudioTrackIndex;

    final track = controller.audioTracks[safeIndex];
    final title = track.title?.trim();
    final language = track.language?.trim();

    if (title != null && title.isNotEmpty) return title;
    if (language != null && language.isNotEmpty) return language.toUpperCase();
    return context.tr('Track {value0}', {'value0': safeIndex + 1});
  }

  String _formatSensitivity(BuildContext context, double sensitivity) {
    if (sensitivity <= 0.15) return context.tr('Low');
    if (sensitivity <= 0.4) return context.tr('Medium');
    return context.tr('High');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: BottomSheetHandle()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      context.tr('Player Settings'),
                      style: TextStyle(
                        color: theme.strongText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      context.tr('Keep the screen clean and put the extra controls here.'),
                      style: TextStyle(
                        color: theme.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  _SettingsSection(
                    title: context.tr('Playback'),
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.speed,
                          title: context.tr('Playback speed'),
                          subtitle: context.tr('Change the current speed'),
                          value: '${controller.playbackSpeed}x',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => _SettingsSpeedSheet(
                                currentSpeed: controller.playbackSpeed,
                                onSpeedSelected: controller.setSpeed,
                              ),
                            );
                          },
                        ),
                        _SettingsTile(
                          icon: Icons.aspect_ratio,
                          title: context.tr('Aspect ratio'),
                          subtitle: context.tr('Fit, fill, stretch, and classic ratios'),
                          value: _formatAspectRatio(context, controller),
                          onTap: controller.cycleAspectRatio,
                        ),
                        _SettingsTile(
                          icon: Icons.repeat,
                          title: context.tr('Repeat mode'),
                          subtitle: context.tr('Choose what happens at the end'),
                          value: _formatRepeatMode(context, controller),
                          onTap: controller.cycleRepeatMode,
                        ),
                        _SettingsTile(
                          icon: Icons.touch_app,
                          title: context.tr('Double tap seek'),
                          subtitle: context.tr('Seconds to skip per tap'),
                          value: context.tr('{value0}s', {'value0': controller.doubleTapSeekStep}),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => _SeekStepSheet(
                                currentStep: controller.doubleTapSeekStep,
                                onStepSelected: controller.setDoubleTapSeekStep,
                              ),
                            );
                          },
                        ),
                        _SettingsTile(
                          icon: Icons.swipe,
                          title: context.tr('Drag sensitivity'),
                          subtitle: context.tr('How much seek distance covers'),
                          value: _formatSensitivity(context, 
                              controller.dragSeekSensitivity),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => _SensitivitySheet(
                                currentSensitivity:
                                    controller.dragSeekSensitivity,
                                onSensitivitySelected:
                                    controller.setDragSeekSensitivity,
                              ),
                            );
                          },
                        ),
                        _VolumeTile(controller: controller),
                      ],
                    ),
                  ),
                  _SettingsSection(
                    title: context.tr('Tracks & Screen'),
                    child: Column(
                      children: [
                        if (onOpenSubtitleSettings != null)
                          _SettingsTile(
                            icon: Icons.subtitles_outlined,
                            title: context.tr('Subtitle settings'),
                            subtitle: controller.subtitlesEnabled
                                ? context.tr('Customize subtitles')
                                : context.tr('Subtitles are currently off'),
                            value: controller.subtitlesEnabled ? context.tr('On') : context.tr('Off'),
                            onTap: () {
                              Navigator.pop(context);
                              onOpenSubtitleSettings!();
                            },
                          ),
                        if (controller.audioTracks.length > 1)
                          _SettingsTile(
                            icon: Icons.audiotrack,
                            title: context.tr('Audio track'),
                            subtitle: context.tr('Switch language or commentary track'),
                            value: _formatAudioTrack(context, controller),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => _AudioTrackSheet(
                                  audioTracks: controller.audioTracks,
                                  currentIndex:
                                      controller.currentAudioTrackIndex,
                                  onSelected: (index) {
                                    controller.setAudioTrack(index);
                                    Navigator.pop(ctx);
                                  },
                                  onRefresh: () {
                                    controller.loadAudioTracks();
                                    Navigator.pop(ctx);
                                  },
                                ),
                              );
                            },
                          ),
                        _SettingsTile(
                          icon: controller.isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          title: context.tr('Screen mode'),
                          subtitle: context.tr('Toggle portrait and landscape player'),
                          value:
                              controller.isFullscreen ? context.tr('Fullscreen') : context.tr('Inline'),
                          onTap: controller.toggleFullscreen,
                        ),
                        _SettingsTile(
                          icon: controller.isLocked
                              ? Icons.lock
                              : Icons.lock_open,
                          title: context.tr('Lock controls'),
                          subtitle: context.tr('Prevent accidental touches while watching'),
                          value: controller.isLocked ? context.tr('Locked') : context.tr('Unlocked'),
                          onTap: () {
                            controller.toggleLock();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Text(
                      context.tr('Tip: tap the center of the video to show or hide controls.'),
                      style: TextStyle(
                        color: theme.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: theme.subtleSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Text(
                title,
                style: TextStyle(
                  color: theme.strongText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.strongText),
      title: Text(
        title,
        style: TextStyle(color: theme.strongText),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: theme.mutedText, fontSize: 12),
      ),
      trailing: _SettingsValueChip(label: value),
      onTap: onTap,
    );
  }
}

class _VolumeTile extends StatelessWidget {
  final PlayerController controller;

  const _VolumeTile({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Volume'),
            style: TextStyle(
              color: theme.strongText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Icon(Icons.volume_down, color: theme.mutedText, size: 20),
              Expanded(
                child: Slider(
                  value: controller.volume,
                  min: 0,
                  max: 100,
                  activeColor: theme.colorScheme.primary,
                  inactiveColor: Colors.grey.shade700,
                  onChanged: controller.setVolume,
                ),
              ),
              Icon(Icons.volume_up, color: theme.mutedText, size: 20),
              SizedBox(
                width: 42,
                child: Text(
                  '${controller.volume.round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: theme.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsValueChip extends StatelessWidget {
  final String label;

  const _SettingsValueChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsSpeedSheet extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  const _SettingsSpeedSheet({
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  static const List<double> speeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.5,
    3.0,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Playback Speed'),
                    style: TextStyle(
                      color: theme.strongText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${currentSpeed}x',
                    style: TextStyle(
                      color: theme.mutedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.softBorder, height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: speeds.length,
                itemBuilder: (context, index) {
                  final speed = speeds[index];
                  final isSelected = speed == currentSpeed;

                  return ListTile(
                    title: Text(
                      speed == 1.0 ? context.tr('Normal') : '${speed}x',
                      style: TextStyle(
                        color: isSelected ? theme.strongText : theme.mutedText,
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      onSpeedSelected(speed);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AudioTrackSheet extends StatefulWidget {
  final List<AudioTrackInfo> audioTracks;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onRefresh;

  const _AudioTrackSheet({
    required this.audioTracks,
    required this.currentIndex,
    required this.onSelected,
    required this.onRefresh,
  });

  @override
  State<_AudioTrackSheet> createState() => _AudioTrackSheetState();
}

class _AudioTrackSheetState extends State<_AudioTrackSheet> {
  bool _refreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    widget.onRefresh();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Audio Track'),
                    style: TextStyle(
                      color: theme.strongText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        context.tr('{value0} tracks', {'value0': widget.audioTracks.length}),
                        style: TextStyle(
                          color: theme.mutedText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _refreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 20),
                        onPressed: _refreshing ? null : _handleRefresh,
                        tooltip: context.tr('Refresh tracks'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: theme.softBorder, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.audioTracks.length,
                itemBuilder: (context, index) {
                  final track = widget.audioTracks[index];
                  final isSelected = index == widget.currentIndex;

                  return ListTile(
                    title: Text(
                      track.title?.trim().isNotEmpty == true
                          ? track.title!
                          : context.tr('Track {value0}', {'value0': index + 1}),
                      style: TextStyle(
                        color: isSelected ? theme.strongText : theme.mutedText,
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    subtitle: track.language?.trim().isNotEmpty == true
                        ? Text(
                            track.language!,
                            style: TextStyle(
                              color: theme.faintText,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => widget.onSelected(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SeekStepSheet extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int> onStepSelected;

  const _SeekStepSheet({
    required this.currentStep,
    required this.onStepSelected,
  });

  static const List<int> steps = [10, 15, 20, 30, 60];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Double Tap Seek Step'),
                    style: TextStyle(
                      color: theme.strongText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr('{value0}s', {'value0': currentStep}),
                    style: TextStyle(
                      color: theme.mutedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.softBorder, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  final step = steps[index];
                  final isSelected = step == currentStep;

                  return ListTile(
                    title: Text(
                      context.tr('{value0}s', {'value0': step}),
                      style: TextStyle(
                        color: isSelected ? theme.strongText : theme.mutedText,
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      onStepSelected(step);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SensitivitySheet extends StatelessWidget {
  final double currentSensitivity;
  final ValueChanged<double> onSensitivitySelected;

  const _SensitivitySheet({
    required this.currentSensitivity,
    required this.onSensitivitySelected,
  });

  static const List<MapEntry<String, double>> options = [
    MapEntry('Low', 0.15),
    MapEntry('Medium', 0.3),
    MapEntry('High', 0.5),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Drag Sensitivity'),
                    style: TextStyle(
                      color: theme.strongText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr(options
                        .firstWhere(
                          (e) => e.value == currentSensitivity,
                          orElse: () => const MapEntry('Medium', 0.3),
                        )
                        .key),
                    style: TextStyle(
                      color: theme.mutedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: theme.softBorder, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == currentSensitivity;

                  return ListTile(
                    title: Text(
                      context.tr(option.key),
                      style: TextStyle(
                        color: isSelected ? theme.strongText : theme.mutedText,
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      onSensitivitySelected(option.value);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
