import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

/// OpenStreetMap view with round dots (same look as the Figma Safety Map).
class OsmMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<LatLng> points;
  final Color dotColor;
  final void Function(LatLng)? onTap;
  const OsmMap({
    super.key,
    required this.center,
    required this.zoom,
    this.points = const [],
    this.dotColor = AppColors.orange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            onTap: onTap == null ? null : (_, p) => onTap!(p),
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.tileUrl,
              userAgentPackageName: AppConfig.userAgent,
            ),
            MarkerLayer(
              markers: points
                  .map((p) => Marker(
                        point: p,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: Colors.white70,
            child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 11)),
          ),
        ),
      ]);
}
