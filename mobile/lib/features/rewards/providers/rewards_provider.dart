import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Model for a single reward item.
class RewardItem {
  final String id;
  final String type;
  final int value;
  final String? description;
  final bool redeemed;
  final DateTime createdAt;

  RewardItem({
    required this.id,
    required this.type,
    required this.value,
    this.description,
    required this.redeemed,
    required this.createdAt,
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) {
    return RewardItem(
      id: json['id'],
      type: json['type'],
      value: json['value'],
      description: json['description'],
      redeemed: json['redeemed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Wallet summary from the API.
class RewardWallet {
  final int totalPoints;
  final int totalRewards;
  final List<RewardItem> rewards;

  RewardWallet({
    required this.totalPoints,
    required this.totalRewards,
    required this.rewards,
  });

  factory RewardWallet.fromJson(Map<String, dynamic> json) {
    return RewardWallet(
      totalPoints: json['total_points'],
      totalRewards: json['total_rewards'],
      rewards: (json['rewards'] as List)
          .map((e) => RewardItem.fromJson(e))
          .toList(),
    );
  }
}

/// Provider that fetches the user's reward wallet.
final rewardsProvider = FutureProvider<RewardWallet>((ref) async {
  // Wait for authentication state
  final authState = await ref.watch(authStateProvider.future);
  
  // Return empty wallet if not authenticated
  if (authState == null) {
    return RewardWallet(totalPoints: 0, totalRewards: 0, rewards: []);
  }

  final dio = ref.read(dioProvider);

  try {
    final response = await dio.get('/users/me/rewards');
    return RewardWallet.fromJson(response.data);
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to load rewards');
  }
});
