import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';

/// 여행 목록. 로그인 후 첫 화면이다.
class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MapMarker'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: '스냅샷 검증',
              icon: const Icon(Icons.science_outlined),
              onPressed: () => context.go(Routes.snapshotLab),
            ),
        ],
      ),
      body: const Center(child: Text('아직 여행이 없습니다.')),
    );
  }
}
