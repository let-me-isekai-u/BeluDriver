import 'package:flutter/material.dart';
import '../../ui/ui.dart';
import 'driver_gps_tracker.dart';

class DriverLocationTile extends StatelessWidget {
  const DriverLocationTile({super.key});
  @override
  Widget build(BuildContext context) {
    final tracker = DriverGpsTracker.instance;
    return AnimatedBuilder(
      animation: tracker,
      builder: (context, _) => Material(
        color: Brand.b50,
        child: SwitchListTile.adaptive(
          title: const Text(
            'Chia sẻ vị trí khi làm việc',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            tracker.lastError ??
                (tracker.enabled
                    ? 'Đang chia sẻ với Super admin. Tắt khi nghỉ; GPS có thể chạy nền.'
                    : 'Bật để điều hành thấy vị trí, kể cả lúc chưa có chuyến.'),
            style: const TextStyle(fontSize: 12),
          ),
          secondary: Icon(
            tracker.enabled ? Icons.location_on : Icons.location_off,
            color: Brand.navy,
          ),
          value: tracker.enabled,
          onChanged: tracker.busy
              ? null
              : (enabled) {
                  if (enabled) {
                    tracker.start();
                  } else {
                    tracker.stop();
                  }
                },
        ),
      ),
    );
  }
}
