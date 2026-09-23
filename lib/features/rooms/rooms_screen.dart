import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart' show CaseRoom, InvestigationStatus;
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shell/ambient_atmosphere.dart';
import '../auth/auth_providers.dart';
import 'activity_feed.dart';
import 'create_room_dialog.dart';
import 'domain/rooms_repository.dart' show CreatedRoom;
import 'room_detail_screen.dart';
import 'rooms_providers.dart';

// ── Console shell (v3: topbar + rail + cases list + main) ──

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String? _selectedRoomId;
  int _roomTab = 0;

  void _goTab(int index) => setState(() => _roomTab = index.clamp(0, 10));

  void _copyRoomLink() {
    final id = _selectedRoomId;
    final link = id == null
        ? Uri.base.toString()
        : Uri.base.replace(path: '/rooms/$id').toString();
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Case link copied.')));
  }

  /// Account sheet (rail avatar): identity + sign out. The router's
  /// session listener reroutes to /auth on sign-out.
  void _showAccountSheet(BuildContext context) {
    final user = ref.read(sessionProvider).value;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.consolePanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _AvatarChip(initials: _initialsOf(user?.displayName)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Investigator',
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(color: AppColors.consoleMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                key: const Key('account-signout'),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                  } on Exception catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${toAppException(error).message}\n— $error',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsState = ref.watch(roomsProvider);
    final List<CaseRoom> rooms = roomsState is RoomsLoaded
        ? roomsState.rooms
        : List<CaseRoom>.empty();
    final effectiveRoomId = _effectiveSelection(rooms);
    _selectedRoomId = effectiveRoomId;
    final userInitials = _initialsOf(
      ref.watch(sessionProvider).value?.displayName,
    );

    return Scaffold(
      backgroundColor: AppColors.consoleBg,
      body: _consoleShell(
        rooms: rooms,
        selectedRoomId: effectiveRoomId,
        roomsState: roomsState,
        userInitials: userInitials,
      ),
    );
  }

  static String _initialsOf(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'CT';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String? _effectiveSelection(List<CaseRoom> rooms) {
    if (rooms.isEmpty) return null;
    if (_selectedRoomId != null && rooms.any((r) => r.id == _selectedRoomId)) {
      return _selectedRoomId;
    }
    return rooms.first.id;
  }

  Widget _consoleShell({
    required List<CaseRoom> rooms,
    required String? selectedRoomId,
    required RoomsState roomsState,
    required String userInitials,
  }) {
    // Design.md §4 breakpoint: below 600px the left rail + cases panel
    // give way to a bottom navigation bar (v3 §12 mobile shell); room
    // switching moves into a bottom-sheet case switcher.
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final detail = selectedRoomId == null
        ? const _EmptyConsole()
        : RoomDetailScreen(
            key: ValueKey('room-console-$selectedRoomId'),
            roomId: selectedRoomId,
            caseType: _roomType(rooms, selectedRoomId),
            initialTab: _roomTab,
          );
    if (isMobile) {
      return Stack(
        children: [
          const Positioned.fill(child: AmbientAtmosphere()),
          Column(
            children: [
              _TopBar(
                compact: true,
                onCopyLink: _copyRoomLink,
                onAskAI: () => _goTab(7),
                onNotifications: () => _openNotifications(rooms),
              ),
              Expanded(child: detail),
              _BottomNav(
                onCases: () =>
                    _showCaseSwitcher(rooms, selectedRoomId, roomsState),
                onGoTab: _goTab,
                onAccount: () => _showAccountSheet(context),
              ),
            ],
          ),
        ],
      );
    }
    return Stack(
      children: [
        const Positioned.fill(child: AmbientAtmosphere()),
        Column(
          children: [
            _TopBar(onCopyLink: _copyRoomLink, onAskAI: () => _goTab(7)),
            Expanded(
              child: Row(
                children: [
                  _Rail(
                    selectedRoomId: selectedRoomId,
                    userInitials: userInitials,
                    onGoTab: _goTab,
                    onAccount: () => _showAccountSheet(context),
                  ),
                  _CasesPanel(
                    rooms: rooms,
                    selectedRoomId: selectedRoomId,
                    onSelect: (id) => setState(() => _selectedRoomId = id),
                    onGoTab: _goTab,
                    roomsState: roomsState,
                  ),
                  Expanded(child: detail),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Mobile case switcher (v3 §12): the cases panel's list + actions
  /// presented as a bottom sheet when the sidebar cannot fit.
  void _showCaseSwitcher(
    List<CaseRoom> rooms,
    String? selectedRoomId,
    RoomsState roomsState,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.consolePanel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _CaseSwitcherSheet(
        rooms: rooms,
        selectedRoomId: selectedRoomId,
        roomsState: roomsState,
        onSelect: (id) {
          Navigator.of(sheetContext).pop();
          setState(() => _selectedRoomId = id);
        },
        onGoTab: (tab) {
          Navigator.of(sheetContext).pop();
          _goTab(tab);
        },
        onSearch: () => context.push('/search'),
        onTemplates: () => context.push('/templates'),
        onJoin: () => context.push('/join'),
        onCreate: () async {
          final navigator = Navigator.of(sheetContext);
          final created = await showDialog<CreatedRoom>(
            context: context,
            builder: (_) => const CreateRoomDialog(),
          );
          if (created != null) {
            navigator.pop();
            ref.read(roomsProvider.notifier).refresh();
            setState(() => _selectedRoomId = created.roomId);
          }
        },
      ),
    );
  }

  /// Notifications sheet entry point for the mobile topbar — delegates
  /// to the same sheet the desktop cases panel uses.
  void _openNotifications(List<CaseRoom> rooms) {
    _openNotificationsSheet(
      context,
      ref,
      rooms: rooms,
      onSelect: (id) => setState(() => _selectedRoomId = id),
    );
  }

  String _roomType(List<CaseRoom> rooms, String roomId) {
    final match = rooms.where((r) => r.id == roomId);
    return match.isNotEmpty ? match.first.caseType : '';
  }
}

// ═══════════════════════════════════════════════════════════
//  TOP BAR (v3 §4)
// ═══════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onCopyLink,
    required this.onAskAI,
    this.compact = false,
    this.onNotifications,
  });

  final VoidCallback onCopyLink;
  final VoidCallback onAskAI;
  final bool compact;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xCC05060A),
        border: Border(bottom: BorderSide(color: AppColors.consoleBorder)),
      ),
      child: Row(
        children: [
          SizedBox(width: compact ? 12 : 18),
          _LogoMark(),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CaseThread',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.consoleText,
                ),
              ),
              if (!compact)
                Text(
                  'INVESTIGATION CONSOLE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.7,
                    color: AppColors.consoleMuted,
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Mobile topbar: notifications bell + icon-only actions.
          if (compact) ...[
            if (onNotifications != null)
              IconButton(
                key: const Key('mobile-notifications'),
                tooltip: 'Notifications',
                color: const Color(0xFF9AA2B6),
                onPressed: onNotifications,
                icon: Consumer(
                  builder: (context, bellRef, _) {
                    final count = bellRef
                        .watch(activityFeedListProvider)
                        .maybeWhen(data: (l) => l.length, orElse: () => 0);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined, size: 20),
                        if (count > 0)
                          Positioned(
                            right: -5,
                            top: -4,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(minWidth: 15),
                              height: 15,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFB7185),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            _GhostButton(
              key: const Key('topbar-copy-link'),
              icon: Icons.link,
              label: '',
              iconOnly: true,
              onTap: onCopyLink,
            ),
            const SizedBox(width: 6),
            _PrimaryButton(
              key: const Key('topbar-ask-ai'),
              icon: Icons.auto_awesome,
              label: '',
              iconOnly: true,
              onTap: onAskAI,
            ),
          ] else ...[
            _GhostButton(icon: Icons.link, label: 'Copy link', onTap: onCopyLink),
            const SizedBox(width: 8),
            _PrimaryButton(
              icon: Icons.auto_awesome,
              label: 'Ask CaseThread',
              onTap: onAskAI,
            ),
          ],
          SizedBox(width: compact ? 8 : 18),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x26FFFFFF)),
        boxShadow: [BoxShadow(color: const Color(0x456366F1), blurRadius: 30)],
      ),
      child: const Icon(Icons.hub_outlined, size: 18, color: Colors.white),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB30E0E1B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 14 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.consoleText),
              if (!iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.consoleText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 14 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
            border: Border.all(color: const Color(0x6BB4C0FF)),
            boxShadow: [
              BoxShadow(color: const Color(0x4D4F46E5), blurRadius: 28),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              if (!iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  RAIL
// ═══════════════════════════════════════════════════════════════

class _Rail extends StatelessWidget {
  const _Rail({
    required this.selectedRoomId,
    required this.userInitials,
    required this.onGoTab,
    required this.onAccount,
  });

  final String? selectedRoomId;
  final String userInitials;
  final void Function(int) onGoTab;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF07080C),
        border: Border(
          right: BorderSide(
            color: Color.fromARGB(0x1A, 0xFF, 0xFF, 0xFF),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _RailButton(
            icon: _brandIcon(),
            label: 'Cases',
            selected: true,
            onTap: () => onGoTab(0),
          ),
          const SizedBox(height: 8),
          _RailButton(
            icon: const Icon(Icons.checklist, size: 19),
            label: 'Tasks',
            selected: false,
            onTap: () => onGoTab(6),
          ),
          _RailButton(
            icon: const Icon(Icons.trending_up, size: 19),
            label: 'Activity',
            selected: false,
            onTap: () => onGoTab(8),
          ),
          const Spacer(),
          _RailButton(
            icon: _AvatarChip(initials: userInitials),
            label: userInitials,
            selected: false,
            onTap: onAccount,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _brandIcon() {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0x446366F1), blurRadius: 30)],
      ),
      child: const Icon(Icons.dashboard, size: 18, color: Colors.white),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : badge = null;

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? const Color(0x176366F1).withValues(alpha: 0.14)
                : Colors.transparent,
            border: selected
                ? Border.all(color: const Color(0x308180F8), width: 1)
                : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IconTheme(
                  data: IconThemeData(
                    color: selected
                        ? const Color(0xFFA5B4FC)
                        : const Color(0xFF9AA2B6),
                    size: 19,
                  ),
                  child: icon,
                ),
              ),
              if (badge != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xF2F46394),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF07080C),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x28FFFFFF)),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CASES PANEL
// ═══════════════════════════════════════════════════════════════

class _CasesPanel extends ConsumerStatefulWidget {
  const _CasesPanel({
    required this.rooms,
    required this.selectedRoomId,
    required this.onSelect,
    required this.onGoTab,
    required this.roomsState,
  });

  final List<CaseRoom> rooms;
  final String? selectedRoomId;
  final void Function(String) onSelect;
  final void Function(int) onGoTab;
  final RoomsState roomsState;

  @override
  ConsumerState<_CasesPanel> createState() => _CasesPanelState();
}

class _CasesPanelState extends ConsumerState<_CasesPanel> {
  String _filter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final filtered = _filteredRooms();

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF07080C),
        border: Border(
          right: BorderSide(
            color: Color.fromARGB(0x1A, 0xFF, 0xFF, 0xFF),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _panelHeader(text),
          _searchField(),
          _filterChips(),
          _attentionBanner(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final room = filtered[index];
                return _CaseRow(
                  room: room,
                  selected: room.id == widget.selectedRoomId,
                  onTap: () => widget.onSelect(room.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CaseRoom> _filteredRooms() {
    final query = _searchController.text.toLowerCase().trim();
    return widget.rooms.where((r) {
      final matchesFilter =
          _filter == 'all' ||
          _filter == 'open' && r.status == 'active' ||
          _filter == 'investigation' &&
              r.investigationStatus == InvestigationStatus.underInvestigation ||
          _filter == 'review' &&
              r.investigationStatus == InvestigationStatus.review;
      final matchesSearch =
          query.isEmpty ||
          r.name.toLowerCase().contains(query) ||
          r.caseType.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  Widget _panelHeader(TextTheme text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Cases',
              style: text.headlineLarge?.copyWith(fontSize: 22),
            ),
          ),
          IconButton(
            key: const Key('rooms-search'),
            tooltip: 'Search across cases',
            icon: const Icon(Icons.search, size: 18),
            color: const Color(0xFF9AA2B6),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            key: const Key('rooms-templates'),
            tooltip: 'Template marketplace',
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            color: const Color(0xFF9AA2B6),
            onPressed: () => context.push('/templates'),
          ),
          IconButton(
            key: const Key('rooms-join'),
            tooltip: 'Join with a code',
            icon: const Icon(Icons.key_outlined, size: 18),
            color: const Color(0xFF9AA2B6),
            onPressed: () => context.push('/join'),
          ),
          IconButton(
            key: const Key('rooms-create'),
            tooltip: 'Create a new case room',
            icon: const Icon(Icons.add, size: 18),
            color: const Color(0xFF9AA2B6),
            onPressed: () => _openCreate(context),
          ),
          IconButton(
            tooltip: 'Notifications',
            color: const Color(0xFF9AA2B6),
            onPressed: () => _showNotifications(context),
            icon: Consumer(
              builder: (context, bellRef, _) {
                final count = bellRef
                    .watch(activityFeedListProvider)
                    .maybeWhen(data: (l) => l.length, orElse: () => 0);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, size: 18),
                    if (count > 0)
                      Positioned(
                        right: -5,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(minWidth: 15),
                          height: 15,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFB7185),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x99FB7185),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color.fromARGB(0x1A, 0xFF, 0xFF, 0xFF)),
          color: const Color(0xFF0B0D14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, size: 15, color: Color(0xFF9AA2B6)),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Color(0xFFF7F8FC), fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search cases, people or evidence',
                  hintStyle: TextStyle(color: Color(0xFF9AA2B6), fontSize: 13),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      // v3 .seg wraps — four chips don't fit one row at panel width.
      child: Wrap(
        runSpacing: 4,
        children: [
          for (final f in const [
            ('all', 'All'),
            ('open', 'Open'),
            ('investigation', 'Investigating'),
            ('review', 'Review'),
          ])
            _FilterChip(
              key: ValueKey('filter-${f.$1}'),
              label: f.$2,
              pressed: _filter == f.$1,
              onPressed: () => setState(() => _filter = f.$1),
            ),
        ],
      ),
    );
  }

  Widget _attentionBanner() {
    final text = Theme.of(context).textTheme;
    final roomId = widget.selectedRoomId;
    // No room selected → nothing is waiting on you in any case.
    if (roomId == null) return const SizedBox.shrink();

    final counts = ref.watch(attentionCountsProvider(roomId));
    final summary = counts.maybeWhen(
      data: (c) => c.summary,
      orElse: () => 'Checking what needs you…',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      // The banner is a shortcut to the selected room's Tasks tab.
      child: GestureDetector(
        onTap: () => widget.onGoTab(6),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x338180F8)),
            gradient: const LinearGradient(
              colors: [Color(0x1A2563EB), Color(0x0D7C3AED)],
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                margin: const EdgeInsets.only(left: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0x184F70ED), blurRadius: 24),
                  ],
                ),
                child: Icon(
                  counts.maybeWhen(
                    data: (c) => c.isClear ? Icons.done_all : Icons.speed,
                    orElse: () => Icons.speed,
                  ),
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Waiting on you',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      summary,
                      style: text.bodySmall?.copyWith(
                        color: const Color(0xFF9AA2B6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.chevron_right,
                size: 15,
                color: Color(0xFF9AA2B6),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  /// Console notifications (v3 §6 sheet). Delegates to the shared
  /// sheet opener also used by the mobile topbar.
  void _showNotifications(BuildContext context) {
    _openNotificationsSheet(
      context,
      ref,
      rooms: widget.rooms,
      onSelect: widget.onSelect,
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final created = await showDialog<CreatedRoom>(
      context: context,
      builder: (_) => const CreateRoomDialog(),
    );
    if (created != null && context.mounted) {
      ref.read(roomsProvider.notifier).refresh();
      widget.onSelect(created.roomId);
      context.push('/rooms/${created.roomId}');
    }
  }
}

class _FilterChip extends ConsumerWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.pressed,
    required this.onPressed,
  });

  final String label;
  final bool pressed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(
          label[0].toUpperCase() + label.substring(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: pressed ? const Color(0xFFA5B4FC) : const Color(0xFF9AA2B6),
          ),
        ),
        selected: pressed,
        onSelected: (_) => onPressed(),
        selectedColor: const Color(0x1A6366F1),
        side: BorderSide(
          color: pressed
              ? const Color(0x4D8180F8)
              : Color.fromARGB(0x1A, 0xFF, 0xFF, 0xFF),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CASE ROW
// ═══════════════════════════════════════════════════════════════

class _CaseRow extends StatelessWidget {
  const _CaseRow({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final CaseRoom room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final statusColor = _statusColor(room.investigationStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(color: const Color(0x2D8180F8), width: 1)
                : null,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x176366F1), Color(0x0D8B5CF6)],
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _relativeTime(room.createdAt),
                          style: text.bodySmall?.copyWith(
                            color: const Color(0xFF9AA2B6),
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${room.caseType} · ${room.status}',
                      style: text.bodySmall?.copyWith(
                        color: const Color(0xFF9AA2B6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _Badge(
                          color: statusColor,
                          label: _investigationLabel(room.investigationStatus),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${room.id.substring(0, room.id.length > 4 ? 4 : room.id.length)}',
                          style: text.bodySmall?.copyWith(
                            color: const Color(0xFF9AA2B6),
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(InvestigationStatus status) {
    return switch (status) {
      InvestigationStatus.open => const Color(0xFF6193FF),
      InvestigationStatus.underInvestigation => const Color(0xFF4EE3B8),
      InvestigationStatus.review => const Color(0xFFE1A66B),
      InvestigationStatus.closed => const Color(0xFF8C99A8),
    };
  }

  String _investigationLabel(InvestigationStatus status) {
    return switch (status) {
      InvestigationStatus.open => 'OPEN',
      InvestigationStatus.underInvestigation => 'INVESTIGATING',
      InvestigationStatus.review => 'REVIEW',
      InvestigationStatus.closed => 'CLOSED',
    };
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  EMPTY CONSOLE
// ═══════════════════════════════════════════════════════════════

class _EmptyConsole extends ConsumerWidget {
  const _EmptyConsole();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    // Already inside the console's main area (after rail + panel) —
    // no manual offset needed; just center the empty state.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4FE0FF),
                  Color(0xFF816CFF),
                  Color(0xFFFF65CE),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 100,
                ),
                BoxShadow(color: const Color(0x446366F1), blurRadius: 40),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      color: Color.fromARGB(0x86, 0x03, 0x0A, 0x1C),
                    ),
                  ),
                ),
                Center(
                  child: Icon(Icons.trending_up, size: 30, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Open a case to start work',
            style: text.headlineLarge?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.04,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Evidence, reconstructed timeline, contradiction '
            'analysis and the team thread all live inside a '
            'single case room.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB7C6DC),
              height: 1.65,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            key: const Key('rooms-create-empty'),
            onPressed: () => _openCreate(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('New room'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<CreatedRoom>(
      context: context,
      builder: (_) => const CreateRoomDialog(),
    );
    if (created != null && context.mounted) {
      ref.read(roomsProvider.notifier).refresh();
      context.push('/rooms/${created.roomId}');
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  SHARED NOTIFICATIONS SHEET (v3 §6)
// ═══════════════════════════════════════════════════════════════

/// The global unseen-activity feed (0014). Shared by the desktop
/// cases panel and the mobile topbar so both entry points stay in
/// sync; tapping a row opens that case and marks it seen.
void _openNotificationsSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<CaseRoom> rooms,
  required ValueChanged<String> onSelect,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.consolePanel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Consumer(
      builder: (context, sheetRef, _) {
        final feed = sheetRef.watch(activityFeedListProvider);
        final nameOf = {for (final r in rooms) r.id: r.name};
        return SizedBox(
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.consoleMuted,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.consoleBorder),
              Expanded(
                child: feed.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        toAppException(error).message,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? Center(
                          child: Text(
                            'You are all caught up.',
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.consoleMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              leading: Icon(
                                feedIconFor(item.actionType),
                                size: 20,
                                color: AppColors.v3Info,
                              ),
                              title: Text(
                                item.label,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                nameOf[item.roomId] ?? 'Case room',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.consoleMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                timeAgoShort(item.createdAt),
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.consoleMuted,
                                      fontFamily: 'GeistMono',
                                    ),
                              ),
                              onTap: () {
                                sheetRef
                                    .read(activityFeedRepositoryProvider)
                                    .markRoomSeen(item.roomId)
                                    .catchError((_) {});
                                sheetRef.invalidate(activityFeedListProvider);
                                Navigator.of(sheetContext).pop();
                                onSelect(item.roomId);
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

IconData feedIconFor(String action) => switch (action) {
  'evidence_uploaded' => Icons.description_outlined,
  'code_rotated' => Icons.key_outlined,
  'join_requested' => Icons.person_add_alt_1_outlined,
  'join_approved' => Icons.how_to_reg_outlined,
  'member_revoked' => Icons.person_remove_outlined,
  'task_created' || 'task_updated' => Icons.checklist,
  'timeline_event_edited' => Icons.edit_outlined,
  'room_created' => Icons.hub_outlined,
  _ => Icons.bolt_outlined,
};

String timeAgoShort(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) return '${diff.inDays}d';
  if (diff.inHours > 0) return '${diff.inHours}h';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m';
  return 'now';
}

// ═══════════════════════════════════════════════════════════
//  MOBILE CASE SWITCHER + BOTTOM NAV (v3 §12)
// ═══════════════════════════════════════════════════════════════

/// Bottom-sheet case switcher for the mobile shell: the cases panel's
/// action row + room list in a sheet, since the 340px sidebar cannot
/// fit below the 600px breakpoint.
class _CaseSwitcherSheet extends StatelessWidget {
  const _CaseSwitcherSheet({
    required this.rooms,
    required this.selectedRoomId,
    required this.roomsState,
    required this.onSelect,
    required this.onGoTab,
    required this.onSearch,
    required this.onTemplates,
    required this.onJoin,
    required this.onCreate,
  });

  final List<CaseRoom> rooms;
  final String? selectedRoomId;
  final RoomsState roomsState;
  final ValueChanged<String> onSelect;
  final void Function(int) onGoTab;
  final VoidCallback onSearch;
  final VoidCallback onTemplates;
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cases',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 22),
                    ),
                  ),
                  IconButton(
                    key: const Key('switcher-search'),
                    tooltip: 'Search across cases',
                    icon: const Icon(Icons.search, size: 18),
                    color: const Color(0xFF9AA2B6),
                    onPressed: onSearch,
                  ),
                  IconButton(
                    key: const Key('switcher-templates'),
                    tooltip: 'Template marketplace',
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    color: const Color(0xFF9AA2B6),
                    onPressed: onTemplates,
                  ),
                  IconButton(
                    key: const Key('switcher-join'),
                    tooltip: 'Join with a code',
                    icon: const Icon(Icons.key_outlined, size: 18),
                    color: const Color(0xFF9AA2B6),
                    onPressed: onJoin,
                  ),
                  IconButton(
                    key: const Key('switcher-create'),
                    tooltip: 'Create a new case room',
                    icon: const Icon(Icons.add, size: 18),
                    color: const Color(0xFF9AA2B6),
                    onPressed: onCreate,
                  ),
                ],
              ),
            ),
            Expanded(
              child: rooms.isEmpty
                  ? Center(
                      child: Text(
                        'No case rooms yet — create one to start.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.consoleMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return _CaseRow(
                          room: room,
                          selected: room.id == selectedRoomId,
                          onTap: () => onSelect(room.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mobile bottom navigation (v3 §12): replaces the left rail below
/// the 600px breakpoint. 56px-tall touch targets; icon + label pair
/// so color is never the only signal (Rules.md §8).
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.onCases,
    required this.onGoTab,
    required this.onAccount,
  });

  final VoidCallback onCases;
  final void Function(int) onGoTab;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF07080C),
        border: Border(
          top: BorderSide(color: Color(0x1AFFFFFF)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavDest(
              key: const Key('mobile-nav-cases'),
              icon: Icons.dashboard_outlined,
              label: 'Cases',
              onTap: onCases,
            ),
            _NavDest(
              key: const Key('mobile-nav-tasks'),
              icon: Icons.checklist,
              label: 'Tasks',
              onTap: () => onGoTab(6),
            ),
            _NavDest(
              key: const Key('mobile-nav-ai'),
              icon: Icons.auto_awesome,
              label: 'AI',
              onTap: () => onGoTab(7),
            ),
            _NavDest(
              key: const Key('mobile-nav-activity'),
              icon: Icons.trending_up,
              label: 'Activity',
              onTap: () => onGoTab(8),
            ),
            _NavDest(
              key: const Key('mobile-nav-account'),
              icon: Icons.person_outline,
              label: 'Account',
              onTap: onAccount,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDest extends StatelessWidget {
  const _NavDest({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: const Color(0xFF9AA2B6)),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9AA2B6),
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
