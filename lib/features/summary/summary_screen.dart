import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/activity_event.dart';
import '../../core/models/gitlab_user.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme_mode_controller.dart';
import '../../shared/activity_labels.dart';
import '../../shared/merge_request_labels.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';
import '../activity/push_detail_screen.dart';
import '../branches/branches_screen.dart';
import '../merge_requests/merge_requests_screen.dart';
import '../pending/pending_screen.dart';
import '../projects/projects_screen.dart';

// Alto de los accesos directos y cuánto se montan sobre la cabecera.
const _shortcutHeight = 104.0;
const _shortcutOverlap = 44.0;

/// Home: el informe personal, con la actividad como cuerpo.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(activityFeedProvider);

    // La cabecera es teal en los dos temas: iconos de la barra de estado claros.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.read(gitlabRepositoryProvider).cache.markFresh();
            ref.invalidate(recentEventsProvider);
            ref.invalidate(activitySummaryProvider);
            ref.invalidate(pendingWorkProvider);
            ref.invalidate(openMergeRequestsByScopeProvider);
            ref.invalidate(projectsProvider);
            await ref.read(activityFeedProvider.notifier).refresh();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 400) {
                ref.read(activityFeedProvider.notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _Header()),
                const SliverToBoxAdapter(child: _OfflineBanner()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(
                      'Actividad',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                ..._feedSlivers(context, ref, feed),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ActivityFeedState> feed,
  ) {
    if (feed.isLoading && !feed.hasValue) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (feed.hasError && !feed.hasValue) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ErrorView(
              error: feed.error!,
              onRetry: () => ref.invalidate(activityFeedProvider),
            ),
          ),
        ),
      ];
    }

    final state = feed.valueOrNull;
    if (state == null) return const [];

    if (state.events.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyView(
              icon: Icons.history,
              title: 'Sin actividad reciente',
              message: 'Cuando hagas push a algún proyecto, aparecerá aquí.',
            ),
          ),
        ),
      ];
    }

    // Encabezados de día intercalados con los eventos, en una sola lista.
    final entries = <Object>[];
    String? currentDay;
    for (final event in state.events) {
      final day = dayLabel(event.createdAt);
      if (day != currentDay) {
        entries.add(day);
        currentDay = day;
      }
      entries.add(event);
    }

    return [
      SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) => switch (entries[index]) {
          final String day => _DayHeader(label: day),
          final ActivityEvent event => _ActivityTile(event: event),
          _ => const SizedBox.shrink(),
        },
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: state.loadingMore
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : state.hasMore
                ? const SizedBox.shrink()
                : Text(
                    'No hay más actividad',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }
}

/// Cabecera teal: quién eres, la campana, los números del periodo y, montados
/// sobre su borde, los accesos al resto de secciones.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final colors = MergedColors.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                top + 12,
                8,
                _shortcutOverlap + 22,
              ),
              decoration: BoxDecoration(
                color: colors.header,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(child: _Profile()),
                      _PendingBell(),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Últimos ${activityWindow.inDays} días',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: colors.onHeaderMuted),
                  ),
                  const SizedBox(height: 4),
                  const _PeriodStats(),
                ],
              ),
            ),
            const SizedBox(height: _shortcutHeight - _shortcutOverlap),
          ],
        ),
        const Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          height: _shortcutHeight,
          child: _Shortcuts(),
        ),
      ],
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentUserProvider);
    final user = async.valueOrNull;
    final colors = MergedColors.of(context);
    final theme = Theme.of(context);

    // valueOrNull es null tanto cargando como al fallar: sin mirar el estado,
    // el encabezado se quedaba en "Cargando…" para siempre.
    final failed = async.hasError && !async.hasValue;
    final name =
        user?.name ?? (failed ? 'No se pudo cargar tu perfil' : 'Cargando…');

    // Sobre la cabecera teal, el tinte teal del tema no se vería.
    final overlay = colors.onHeader.withValues(alpha: 0.12);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      hoverColor: overlay,
      highlightColor: overlay,
      splashColor: overlay,
      onTap: failed
          ? () => ref.invalidate(currentUserProvider)
          : () => _showProfileSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _Avatar(user: user, radius: 22, failed: failed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onHeader,
                    ),
                  ),
                  Text(
                    user != null
                        ? '@${user.username}'
                        : (failed ? 'Toca para reintentar' : ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onHeaderMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
    required this.radius,
    this.failed = false,
  });

  final GitlabUser? user;
  final double radius;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = MergedColors.of(context);
    final url = user?.avatarUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.onHeader.withValues(alpha: 0.16),
      foregroundColor: colors.onHeader,
      backgroundImage: url != null ? NetworkImage(url) : null,
      // Si la imagen no carga (avatar privado, red caída) se ven las iniciales.
      onBackgroundImageError: url != null ? (_, _) {} : null,
      child: url != null
          ? null
          : user != null
          ? Text(
              _initials(user!.name),
              style: TextStyle(
                fontSize: radius * 0.72,
                fontWeight: FontWeight.w600,
              ),
            )
          : Icon(failed ? Icons.person_off_outlined : Icons.person_outline),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

class _PeriodStats extends ConsumerWidget {
  const _PeriodStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activitySummaryProvider);
    final summary = activity.valueOrNull;
    final loading = activity.isLoading && summary == null;

    return Row(
      children: [
        _Stat(value: summary?.commits, label: 'commits', loading: loading),
        _Stat(value: summary?.pushes, label: 'pushes', loading: loading),
        _Stat(
          value: summary?.activeDays,
          label: 'días activos',
          loading: loading,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.loading,
  });

  final int? value;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = MergedColors.of(context);
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: loading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onHeader,
                      ),
                    )
                  : Text(
                      value?.toString() ?? '—',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.onHeader,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onHeaderMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Las tres secciones con pantalla propia. Son la única vía de navegación de
/// la home, así que se distinguen de los números informativos de la cabecera.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = MergedColors.of(context);
    final openMrs = ref.watch(openMergeRequestsProvider);
    final mrs = openMrs.valueOrNull;
    final branches = ref.watch(createdBranchesProvider).valueOrNull?.length;
    final projects = ref.watch(projectsProvider).valueOrNull?.length;
    final landing = MrScope.values.firstWhere(
      (scope) => scope.apiValue == mrs?.firstScopeWithItems,
      orElse: () => MrScope.created,
    );

    void open(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Row(
      children: [
        _ShortcutTile(
          icon: Icons.merge_type,
          tone: colors.purple,
          value: mrs?.count,
          capped: mrs?.capped ?? false,
          loading: openMrs.isLoading,
          label: mrs?.count == 1 ? 'MR abierto' : 'MRs abiertos',
          onTap: () => open(MergeRequestsScreen(initialScope: landing)),
        ),
        const SizedBox(width: 10),
        _ShortcutTile(
          icon: Icons.call_split,
          tone: colors.amber,
          value: branches,
          loading: ref.watch(createdBranchesProvider).isLoading,
          label: branches == 1 ? 'Rama nueva' : 'Ramas nuevas',
          onTap: () => open(const BranchesScreen()),
        ),
        const SizedBox(width: 10),
        _ShortcutTile(
          icon: Icons.folder_outlined,
          tone: colors.blue,
          value: projects,
          loading: ref.watch(projectsProvider).isLoading,
          label: projects == 1 ? 'Proyecto' : 'Proyectos',
          onTap: () => open(const ProjectsScreen()),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.tone,
    required this.value,
    required this.loading,
    required this.label,
    required this.onTap,
    this.capped = false,
  });

  final IconData icon;
  final Tone tone;
  final int? value;
  final bool loading;

  /// Hay más de los que se descargaron: el número es un mínimo.
  final bool capped;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: dark ? scheme.surfaceContainerHigh : scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ToneIcon(icon: icon, tone: tone, size: 30),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 18, color: scheme.outline),
                  ],
                ),
                const Spacer(),
                Text(
                  loading && value == null
                      ? '·'
                      : value == null
                      ? '—'
                      : '$value${capped ? '+' : ''}',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campana: ¿me están esperando? El cero se muestra; ocultarlo no
/// distinguiría "nada pendiente" de "aún no ha cargado".
class _PendingBell extends ConsumerWidget {
  const _PendingBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWorkProvider);
    final colors = MergedColors.of(context);

    final Widget icon;
    if (pending.isLoading && !pending.hasValue) {
      icon = SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.onHeader,
        ),
      );
    } else if (pending.hasError && !pending.hasValue) {
      icon = Icon(
        Icons.notifications_off_outlined,
        color: colors.onHeaderMuted,
      );
    } else {
      final count = pending.valueOrNull?.length ?? 0;
      final quiet = count == 0;
      icon = Badge(
        label: Text('$count'),
        backgroundColor: quiet
            ? colors.onHeader.withValues(alpha: 0.22)
            : colors.badge,
        textColor: quiet ? colors.onHeader : colors.onBadge,
        child: Icon(
          quiet ? Icons.notifications_none_outlined : Icons.notifications,
          color: colors.onHeader,
        ),
      );
    }

    return IconButton(
      tooltip: 'Pendientes',
      icon: icon,
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const PendingScreen())),
    );
  }
}

/// Avisa de que los datos vienen de disco: sin esto, unos de hace horas no
/// se distinguen de los recién traídos.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(gitlabRepositoryProvider).cache;
    final tone = MergedColors.of(context).amber;
    final theme = Theme.of(context);

    return ValueListenableBuilder<DateTime?>(
      valueListenable: cache.servingFrom,
      builder: (context, savedAt, _) {
        if (savedAt == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 16, color: tone.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin conexión · datos guardados ${relativeTime(savedAt)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tone.foreground,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final project = ref.watch(projectsByIdProvider)[event.projectId];
    // Los eventos solo traen project_id: el nombre sale del índice local.
    final projectName = project?.name ?? 'Proyecto ${event.projectId}';
    final projectFullName = project?.nameWithNamespace ?? projectName;

    final push = event.pushData;
    final action = describeActivity(event);

    final String title;
    final String subtitle;
    if (push != null) {
      final commits = switch (push.commitCount) {
        0 => '',
        1 => ' · 1 commit',
        final n => ' · $n commits',
      };
      title = push.commitTitle ?? push.ref;
      subtitle = '$projectName · ${push.ref}$commits';
    } else {
      // En un evento de alta, target_title es el propio nombre del proyecto, y
      // repetirlo arriba y abajo no decía qué había ocurrido.
      final label = event.targetTitle ?? projectName;
      title = label;
      subtitle = label == projectName ? action : '$action · $projectName';
    }

    // Todo evento lleva a algún sitio: al detalle si es un push, a su objeto en
    // GitLab si lo tiene, y al proyecto en el resto de casos.
    final targetPath = event.targetPath;
    final destination = (project?.webUrl != null && targetPath != null)
        ? '${project!.webUrl}$targetPath'
        : project?.webUrl;

    final VoidCallback onTap;
    if (push != null) {
      onTap = () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PushDetailScreen(event: event, projectName: projectFullName),
        ),
      );
    } else {
      onTap = () => openInGitlab(context, destination);
    }

    // Con el día ya en el encabezado, la hora dice más que "hace 3 días".
    final when = isToday(event.createdAt)
        ? relativeTime(event.createdAt)
        : clockTime(event.createdAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToneIcon(
              icon: activityIcon(event),
              tone: activityTone(event, MergedColors.of(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  when,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (push == null) ...[
                  const SizedBox(height: 6),
                  Icon(Icons.open_in_new, size: 14, color: scheme.outline),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showProfileSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _ProfileSheet(),
  );
}

/// Lo que antes ocupaba la barra superior: tema, licencias y cerrar sesión.
class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet();

  static const _menuPadding = EdgeInsets.symmetric(horizontal: 12);
  static const _menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        // Las opciones llegan hasta 8 px del borde para que su resaltado
        // respire; el resto del contenido va a 20, alineado con sus iconos.
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(_Avatar._initials(user.name))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                '@${user.username}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Tema',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        for (final option in ThemeMode.values)
                          ButtonSegment(
                            value: option,
                            icon: Icon(themeModeIcon(option), size: 18),
                            label: Text(themeModeLabel(option)),
                          ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (selection) => ref
                          .read(themeModeProvider.notifier)
                          .set(selection.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (user?.webUrl != null)
              ListTile(
                contentPadding: _menuPadding,
                shape: _menuShape,
                leading: const Icon(Icons.person_outline),
                title: const Text('Ver mi perfil en GitLab'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openInGitlab(context, user!.webUrl),
              ),
            ListTile(
              contentPadding: _menuPadding,
              shape: _menuShape,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Licencias'),
              onTap: () =>
                  showLicensePage(context: context, applicationName: 'Merged'),
            ),
            ListTile(
              contentPadding: _menuPadding,
              shape: _menuShape,
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                'Cerrar sesión',
                style: TextStyle(color: scheme.error),
              ),
              onTap: () async {
                // Se cierra la hoja antes: si no, quedaría encima del login.
                // Y se capturan antes de cerrar, porque cerrar desmonta este ref.
                final auth = ref.read(authServiceProvider);
                final container = ProviderScope.containerOf(
                  context,
                  listen: false,
                );
                Navigator.of(context).pop();
                await auth.logout();
                container.invalidate(sessionProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
