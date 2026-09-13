import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../services/remote_config_service.dart';
import 'animations.dart';
import 'common.dart';

/// Announcement card — a real notice pushed from the MoneyBag Admin API.
///
/// Appears on the dashboard while an announcement is active and not yet
/// dismissed ("বুঝেছি" hides it for good — the admin can always push a new
/// one with a different id).
class MbAnnouncementCard extends StatelessWidget {
  const MbAnnouncementCard({super.key});

  @override
  Widget build(BuildContext context) {
    final L = context.L;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: MbRemoteConfigService.instance,
      builder: (context, _) {
        final ann = MbRemoteConfigService.instance.activeAnnouncement;
        if (ann == null) return const SizedBox.shrink();

        final (icon, tint) = switch (ann.kind) {
          'update' => (Icons.system_update_alt_rounded, const Color(0xFF4DABF7)),
          'promo' => (Icons.local_offer_rounded, MbPalette.warning),
          _ => (Icons.campaign_rounded, MbPalette.green),
        };

        return MbFadeSlideIn(
          index: 1,
          child: MbCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: tint, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: tint.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              L.announcementLabel,
                              style: TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: tint,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ann.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'NotoSansBengali',
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ann.body,
                        style: TextStyle(
                          fontFamily: 'NotoSansBengali',
                          fontSize: 12.5,
                          height: 1.45,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => MbRemoteConfigService.instance
                              .dismissCurrentAnnouncement(),
                          child: Text(L.announcementDismiss),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
