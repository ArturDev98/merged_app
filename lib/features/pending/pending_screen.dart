import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/pending_work.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/merge_request_labels.dart';
import '../../shared/open_in_gitlab.dart';
import '../merge_requests/merge_requests_screen.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';

/// La lista que hay detrás de la campana.
class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWorkProvider);

    // Los MRs vienen de descargas compartidas con la home: se invalidan aparte,
    // o seguirían sirviendo el resultado (o el error) anterior.
    Future<void> reload() async {
      ref.invalidate(openMergeRequestsByScopeProvider);
      ref.invalidate(pendingWorkProvider);
      await ref.read(pendingWorkProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendientes'),
        actions: [
          IconButton(
            tooltip: 'Ver merge requests a revisar',
            icon: const Icon(Icons.merge_type),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const MergeRequestsScreen(initialScope: MrScope.reviewing),
              ),
            ),
          ),
        ],
      ),
      body: pending.view(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ErrorView(error: error, onRetry: reload),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: EmptyView(
                icon: Icons.check_circle_outline,
                title: 'Nada pendiente',
                message: 'Nadie está esperando por ti ahora mismo.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(indent: 68),
              itemBuilder: (context, index) => _PendingTile(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.item});

  final PendingItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ToneIcon(
        icon: _iconFor(item.kind),
        tone: _toneFor(item.kind, MergedColors.of(context)),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.reason} · ${relativeTime(item.at)}'),
      trailing: Icon(
        Icons.open_in_new,
        size: 18,
        color: Theme.of(context).colorScheme.outline,
      ),
      onTap: () => openInGitlab(context, item.webUrl),
    );
  }

  static IconData _iconFor(PendingKind kind) => switch (kind) {
    PendingKind.todo => Icons.notifications_active_outlined,
    PendingKind.reviewRequest => Icons.rate_review_outlined,
    PendingKind.assigned => Icons.assignment_ind_outlined,
  };

  static Tone _toneFor(PendingKind kind, MergedColors colors) => switch (kind) {
    PendingKind.todo => colors.coral,
    PendingKind.reviewRequest => colors.purple,
    PendingKind.assigned => colors.blue,
  };
}
