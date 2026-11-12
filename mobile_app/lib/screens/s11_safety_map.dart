import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';

/// S11 Safety Map. Works without login. Shows anonymous reports only.
/// Never shows SOS events or personal locations.
class S11SafetyMap extends StatelessWidget {
  const S11SafetyMap({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final pts = AppState.I.reports
            .where((r) => r.lat != null && r.lng != null)
            .map((r) => LatLng(r.lat!, r.lng!))
            .toList();
        final center = pts.isEmpty ? AppConfig.campusCenter : pts.first;
        final zoom = pts.isEmpty ? AppConfig.campusZoom : 15.0;
        return Scaffold(
          appBar: AppBar(title: const Text('Safety Map')),
          body: SafeArea(
            child: Column(children: [
              Expanded(
                child: Stack(children: [
                  OsmMap(center: center, zoom: zoom, points: pts),
                  if (pts.isEmpty)
                    const Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: AppCard(
                        child: Text('No reports with a map location yet.',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  child: Row(children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: AppColors.orange, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Anonymous reports',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text('Shows reports only. No SOS or personal locations are ever shown.',
                            style: TextStyle(color: AppColors.muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
