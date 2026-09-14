import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../services/remote_config_service.dart';
import '../state/app_state.dart';
import '../widgets/ad_banner.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// Notification center — reminders, device health and the notice feed.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _permGranted = true;
  bool _batteryIgnored = true;

  @override
  void initState() {
    super.initState();
    _reloadDeviceState();
  }

  Future<void> _reloadDeviceState() async {
    final perm = await MbNotifications.instance.isPermissionGranted();
    final batt = await MbNotifications.instance.isBatteryIgnored();
    if (!mounted) return;
    setState(() {
      _permGranted = perm;
      _batteryIgnored = batt;
    });
  }

  Future<void> _afterChange(MbAppState state) async {
    await MbNotifications.instance.applySchedule(state);
  }

  Future<void> _toggleDaily(MbAppState state, bool v) async {
    if (v) {
      final ok = await MbNotifications.instance.requestPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.L.notifDenied)),
          );
        }
        return;
      }
    }
    await state.setDailyReminder(v);
    await _afterChange(state);
  }

  Future<void> _pickTime(MbAppState state) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: state.dailyReminderHour,
        minute: state.dailyReminderMinute,
      ),
    );
    if (picked == null) return;
    await state.setDailyReminder(true,
        hour: picked.hour, minute: picked.minute);
    await _afterChange(state);
  }

  String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          L.notifCenterTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Reminders ──
            _Section(label: L.notifSectionReminders),
            MbFadeSlideIn(
              index: 0,
              child: MbCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary:
                        const Icon(Icons.notifications_active_rounded),
                    title: Text(L.notifDailyReminder),
                    subtitle: Text(L.notifDailyReminderHelp),
                    value: state.dailyReminder,
                    onChanged: (v) => _toggleDaily(state, v),
                  ),
                  Divider(color: scheme.outlineVariant, height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(L.notifDailyTime),
                    subtitle: Text(
                      _hhmm(
                          state.dailyReminderHour, state.dailyReminderMinute),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    trailing: const Icon(Icons.edit_rounded, size: 19),
                    onTap: () => _pickTime(state),
                  ),
                  Divider(color: scheme.outlineVariant, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.calendar_view_week_rounded),
                    title: Text(L.settingsWeeklySummary),
                    subtitle: Text(L.settingsWeeklySummaryHelp),
                    value: state.weeklySummary,
                    onChanged: (v) async {
                      await state.setWeeklySummary(v);
                      await _afterChange(state);
                    },
                  ),
                  Divider(color: scheme.outlineVariant, height: 1),
                  // ── v2.2.3: smart notifications (real numbers in the
                  // reminder body) — on by default, one tap to turn off. ──
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome_rounded),
                    title: Text(L.notifSmartToggle),
                    subtitle: Text(L.notifSmartHelp),
                    value: state.smartNotifications,
                    onChanged: (v) async {
                      await state.setSmartNotifications(v);
                      await _afterChange(state);
                    },
                  ),
                ],
              ),
            ),
            ),
            const SizedBox(height: 12),

            // ── v2.2.3: the two classic "reminder kaj kore na" causes, each
            // with a one-tap fix. Hidden when everything is fine. ──
            _DeviceHealthCard(
              permGranted: _permGranted,
              batteryIgnored: _batteryIgnored,
              onOpenPermission: () async {
                await MbNotifications.instance.openNotificationSettings();
                await _reloadDeviceState();
              },
              onAllowBattery: () async {
                await MbNotifications.instance
                    .requestIgnoreBatteryOptimizations();
                await _reloadDeviceState();
              },
            ),
            const SizedBox(height: 20),

            // ── Notices & push feed ──
            _Section(label: L.notifSectionNotices),
            const MbFadeSlideIn(index: 2, child: _NoticesCard()),

            const SizedBox(height: 16),
            // v2.2.5: home-screen-style bottom banner ad.
            const MbAdBanner(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NotoSansBengali',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// v2.2.3: the two OEM-level reasons reminders silently fail, each with a
/// one-tap fix. Renders nothing when both are healthy.
class _DeviceHealthCard extends StatelessWidget {
  final bool permGranted;
  final bool batteryIgnored;
  final Future<void> Function() onOpenPermission;
  final Future<void> Function() onAllowBattery;

  const _DeviceHealthCard({
    required this.permGranted,
    required this.batteryIgnored,
    required this.onOpenPermission,
    required this.onAllowBattery,
  });

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;
    if (permGranted && batteryIgnored) return const SizedBox.shrink();

    return MbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (!permGranted)
            ListTile(
              leading: const Icon(Icons.notifications_off_rounded,
                  color: MbPalette.warning),
              title: Text(
                L.notifPermWarning,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                L.notifPermHelp,
                style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12,
                    color: scheme.onSurfaceVariant),
              ),
              trailing: TextButton(
                onPressed: onOpenPermission,
                child: Text(L.notifPermAction),
              ),
            ),
          if (!permGranted && !batteryIgnored)
            Divider(color: scheme.outlineVariant, height: 1),
          if (!batteryIgnored)
            ListTile(
              leading: const Icon(Icons.battery_alert_rounded,
                  color: MbPalette.warning),
              title: Text(
                L.notifBatteryTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                L.notifBatteryHelp,
                style: TextStyle(
                    fontFamily: 'NotoSansBengali',
                    fontSize: 12,
                    color: scheme.onSurfaceVariant),
              ),
              trailing: TextButton(
                onPressed: onAllowBattery,
                child: Text(L.notifBatteryAction),
              ),
            ),
        ],
      ),
    );
  }
}

/// Admin announcements + received push history.
class _NoticesCard extends StatelessWidget {
  const _NoticesCard();

  String _timeOf(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([
        MbRemoteConfigService.instance,
        MbPushService.instance,
      ]),
      builder: (context, _) {
        final anns = MbRemoteConfigService.instance.announcements
            .where((a) => a.id.isNotEmpty)
            .toList();
        final pushes = MbPushService.instance.history;

        if (anns.isEmpty && pushes.isEmpty) {
          return MbCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none_rounded,
                        size: 30, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    L.notifCenterEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return MbCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final a in anns)
                ListTile(
                  leading: _kindIcon(a.kind),
                  title: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    a.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final p in pushes)
                ListTile(
                  leading: const Icon(Icons.campaign_rounded),
                  title: Text(
                    '${p['title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${p['body'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NotoSansBengali',
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    _timeOf('${p['at'] ?? ''}'),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _kindIcon(String kind) {
    final color = switch (kind) {
      'update' => MbPalette.warning,
      'promo' => MbPalette.green,
      _ => const Color(0xFF3B82F6),
    };
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.15),
      child: Icon(
        kind == 'update'
            ? Icons.system_update_alt_rounded
            : (kind == 'promo' ? Icons.local_offer_rounded : Icons.info_rounded),
        size: 16,
        color: color,
      ),
    );
  }
}
