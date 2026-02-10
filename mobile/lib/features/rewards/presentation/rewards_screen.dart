import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/rewards_provider.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(rewardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Rewards')),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 8),
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(rewardsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (wallet) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(rewardsProvider),
          child: CustomScrollView(
            slivers: [
              // Points summary card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        '${wallet.totalPoints}',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Total Points',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${wallet.totalRewards} rewards earned',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ),

              // Rewards list
              if (wallet.rewards.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_giftcard,
                          size: 64,
                          color: AppColors.divider,
                        ),
                        SizedBox(height: 16),
                        Text('No rewards yet'),
                        Text('Scan QR codes to earn rewards!'),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final reward = wallet.rewards[index];
                      return _RewardTile(reward: reward);
                    }, childCount: wallet.rewards.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final RewardItem reward;

  const _RewardTile({required this.reward});

  IconData _icon() {
    switch (reward.type) {
      case 'points':
        return Icons.stars;
      case 'coupon':
        return Icons.local_offer;
      case 'raffle':
        return Icons.emoji_events;
      case 'product':
        return Icons.inventory_2;
      default:
        return Icons.card_giftcard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(_icon(), color: AppColors.primary),
        ),
        title: Text(
          reward.description ?? '+${reward.value} ${reward.type}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatDate(reward.createdAt),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: reward.type == 'points'
            ? Text(
                '+${reward.value}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
