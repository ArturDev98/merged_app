import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/merge_request_summary.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/merge_request_labels.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';
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
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final scope in MrScope.values) Tab(text: scope.label)],
        ),
      ),
      body: Column(
        children: [
          // Filtro a la vista y no en un menú: se cambia de un toque y siempre
          // se ve cuál está activo, que es lo que explica un vacío.
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              children: [
                for (final option in MrState.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StateChip(
                      label: option.label,
                      selected: option == _state,
                      onSelected: () => setState(() => _state = option),
                    ),
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
          separatorBuilder: (_, _) => const Divider(indent: 68),
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
      leading: ToneIcon(
        icon: mrStateIcon(mr),
        tone: mrStateTone(mr, MergedColors.of(context)),
      ),
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
          Text(
            relativeTime(mr.updatedAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
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

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => onSelected(),
      selectedColor: scheme.primary,
      backgroundColor: scheme.surfaceContainerLow,
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
