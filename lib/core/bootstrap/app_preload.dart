import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_models.dart';

/// First-paint payload fetched on the splash screen so Discover does not
/// flash an empty/loading state after a logged-in cold start.
class AppPreloadData {
  const AppPreloadData({this.feed, this.profile});

  final FeedResponse? feed;
  final UserProfile? profile;
}

final appPreloadProvider = StateProvider<AppPreloadData?>((ref) => null);
