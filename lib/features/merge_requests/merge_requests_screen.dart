import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/merge_request_summary.dart';
import '../../core/providers.dart';
import '../../shared/merge_request_labels.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import 'merge_request_detail_screen.dart';

/// Merge requests del usuario, en tres puntos de vista.
class MergeRequestsScreen extends StatefulWidget {
  const MergeRequestsScreen({super.key, this.initialScope = MrScope.created});

  final MrScope initialScope;

  @override
  State<MergeRequestsScreen> createState() => _MergeRequestsScreenState();
}

class _MergeRequestsScreenState extends State<MergeRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: MrScope.values.length,
    vsync: this,
    initialIndex: MrScope.values.indexOf(widget.initialScope),
  );

  MrState _state = MrState.opened;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge requests'),
        actions: [
          PopupMenuButton<MrState>(
            initialValue: _state,
            tooltip: 'Filtrar por estado',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _state = value),
            itemBuilder: (context) => [
              for (final state in MrState.values)
                PopupMenuItem(value: state, child: Text(state.label)),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final scope in MrScope.values) Tab(text: scope.label)],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  _state.label,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final scope in MrScope.values)
                  _MergeRequestList(scope: scope, state: _state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MergeRequestList extends ConsumerWidget {
  const _MergeRequestList({required this.scope, required this.state});

  final MrScope scope;
  final MrState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (scope: scope.apiValue, state: state.apiValue);
    final async = ref.watch(mergeRequestListProvider(query));

    if (async.isLoading && !async.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (async.hasError && !async.hasValue) {
      return Center(
        child: ErrorView(
          error: async.error!,
          onRetry: () => ref.invalidate(mergeRequestListProvider(query)),
        ),
      );
    }

    final data = async.valueOrNull;
    if (data == null) return const SizedBox.shrink();

    if (data.items.isEmpty) {
      return Center(
        child: EmptyView(
          icon: Icons.merge_type,
          title: 'Nada por aquí',
          // El vacío explica qué filtro está activo: sin eso parece un fallo
          // de carga, y en varias pestañas el vacío es lo normal.
          message:
              '${scope.emptyMessage}\n'
              'Filtro actual: ${state.label.toLowerCase()}.',
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 300) {
          ref.read(mergeRequestListProvider(query).notifier).loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mergeRequestListProvider(query)),
        child: ListView.separated(
          itemCount: data.items.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == data.items.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: data.loadingMore
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          data.hasMore ? '' : '${data.items.length} en total',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                ),
              );
            }
            return _MergeRequestTile(mr: data.items[index]);
          },
        ),
      ),
    );
  }
}

class _MergeRequestTile extends StatelessWidget {
  const _MergeRequestTile({required this.mr});

  final MergeRequestSummary mr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      leading: Icon(mrStateIcon(mr), color: mrStateColor(mr, scheme)),
      title: Text(mr.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        // Nada de pipeline aquí: la lista de la API no lo trae.
        '!${mr.iid} · ${mrStateLabel(mr)} · ${mr.sourceBranch} → '
        '${mr.targetBranch}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(relativeTime(mr.updatedAt), style: theme.textTheme.labelSmall),
          if (mr.userNotesCount > 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mode_comment_outlined,
                  size: 11,
                  color: scheme.outline,
                ),
                const SizedBox(width: 2),
                Text(
                  '${mr.userNotesCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MergeRequestDetailScreen(mr: mr),
        ),
      ),
    );
  }
}
