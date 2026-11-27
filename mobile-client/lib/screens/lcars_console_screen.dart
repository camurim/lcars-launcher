import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../protocol/lcars_protocol.dart';
import '../services/http_panel_service.dart';
import '../services/lcars_controller.dart';
import '../services/local_device_service.dart';
import '../theme/lcars_theme.dart';
import '../widgets/lcars_button.dart';
import '../widgets/lcars_elbow.dart';
import '../widgets/lcars_info_panel.dart';
import '../widgets/lcars_pill_bar.dart';
import 'connection_screen.dart';

class LcarsConsoleScreen extends StatefulWidget {
  final LcarsController controller;

  const LcarsConsoleScreen({super.key, required this.controller});

  @override
  State<LcarsConsoleScreen> createState() => _LcarsConsoleScreenState();
}

class _LcarsConsoleScreenState extends State<LcarsConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _alarmAnim;

  LcarsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _alarmAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    controller.addListener(_syncAlarmAnimation);
    _syncAlarmAnimation();
  }

  void _syncAlarmAnimation() {
    if (controller.hasVisualAlarm) {
      if (!_alarmAnim.isAnimating) {
        _alarmAnim.repeat(reverse: true);
      }
    } else if (_alarmAnim.isAnimating) {
      _alarmAnim.stop();
      _alarmAnim.value = 0.0;
    }
  }

  @override
  void dispose() {
    controller.removeListener(_syncAlarmAnimation);
    _alarmAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, _alarmAnim]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final pcOnline = controller.isPcOnline;
        final editing = controller.blueprintMode;
        final visualAlarm = controller.hasVisualAlarm;
        final pulse = visualAlarm ? _alarmAnim.value : 0.0;
        final redAlertPulse = Color.lerp(
          const Color(0xFF991B1B),
          const Color(0xFFFF2424),
          pulse,
        )!;

        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Cabeçalho LCARS com cotovelo superior esquerdo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LcarsElbow(
                            color: visualAlarm
                                ? redAlertPulse
                                : (editing
                                    ? LcarsColors.skyBlue
                                    : LcarsColors.amber),
                            label: visualAlarm
                                ? 'RED ALERT'
                                : (editing ? l10n.blueprintHeader : 'DECK 47'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LcarsPillBar(
                                  color: visualAlarm
                                      ? redAlertPulse
                                      : (pcOnline
                                          ? LcarsColors.peach
                                          : (controller.standaloneMode
                                              ? LcarsColors.lavender
                                              : LcarsColors.redAlert)),
                                  label: visualAlarm
                                      ? 'RED ALERT • ${controller.layout.profileName}'
                                      : (pcOnline
                                          ? '${controller.layout.profileName} • ${l10n.statusOnline}'
                                          : (controller.standaloneMode
                                              ? '${controller.layout.profileName} • ${l10n.statusStandalone}'
                                              : '${controller.layout.profileName} • ${l10n.statusStandbyOffline}')),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  controller.statusLog.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: visualAlarm
                                        ? redAlertPulse
                                        : LcarsColors.skyBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Corpo principal: coluna lateral LCARS + grade dinâmica configurável
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Coluna lateral LCARS
                            SizedBox(
                              width: 92,
                              child: Column(
                                children: [
                                  _SideBarTile(
                                    label: l10n.sideConnect,
                                    color: LcarsColors.lavender,
                                    onTap: () {
                                      unawaited(controller.feedback.playTap());
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ConnectionScreen(
                                            controller: controller,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  _SideBarTile(
                                    label: controller.standaloneMode
                                        ? l10n.sideStandalone
                                        : l10n.sidePcLink,
                                    color: controller.standaloneMode
                                        ? LcarsColors.peach
                                        : LcarsColors.offlineGrey,
                                    onTap: () => unawaited(
                                      controller.toggleStandaloneMode(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _SideBarTile(
                                    label: controller.keepScreenOn
                                        ? l10n.sideScreenOn
                                        : l10n.sideScreenAuto,
                                    color: controller.keepScreenOn
                                        ? LcarsColors.skyBlue
                                        : LcarsColors.offlineGrey,
                                    onTap: () => unawaited(
                                      controller.toggleKeepScreenOn(),
                                    ),
                                  ),
                                  if (controller.hasSoundAlarm) ...[
                                    const SizedBox(height: 6),
                                    _SideBarTile(
                                      label: controller.alarmMuted
                                          ? l10n.sideAlarmUnmute
                                          : l10n.sideAlarmMute,
                                      color: redAlertPulse,
                                      onTap: controller.toggleAlarmMute,
                                    ),
                                  ],
                                  if (editing) ...[
                                    const SizedBox(height: 6),
                                    _SideBarTile(
                                      label: l10n.sideAddBlock,
                                      color: LcarsColors.peach,
                                      onTap: () =>
                                          _openBlockEditor(context, null),
                                    ),
                                    const SizedBox(height: 6),
                                    _SideBarTile(
                                      label: l10n.sideBackup,
                                      color: LcarsColors.lavender,
                                      onTap: () => _openBackupDialog(context),
                                    ),
                                    const SizedBox(height: 6),
                                    _SideBarTile(
                                      label: l10n.sideDone,
                                      color: LcarsColors.skyBlue,
                                      onTap: controller.toggleBlueprintMode,
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 6),
                                    _SideBarTile(
                                      label: l10n.sideEditPanel,
                                      color: LcarsColors.gold,
                                      onTap: controller.toggleBlueprintMode,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: LcarsElbow(
                                      color: visualAlarm
                                          ? redAlertPulse
                                          : LcarsColors.amber,
                                      width: 92,
                                      height: double.infinity,
                                      barThickness: 20,
                                      corner: LcarsElbowCorner.bottomLeft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Área direita: faixa de páginas (abas LCARS) + Grade Dinâmica
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (controller.layout.pages.length > 1 ||
                                      editing) ...[
                                    SizedBox(
                                      height: 32,
                                      child: ListView(
                                        scrollDirection: Axis.horizontal,
                                        children: [
                                          for (var i = 0;
                                              i <
                                                  controller
                                                      .layout.pages.length;
                                              i++) ...[
                                            _PageTabChip(
                                              title: controller
                                                  .layout.pages[i].title,
                                              color: LcarsColors.fromToken(
                                                controller.layout.pages[i]
                                                    .accentColor,
                                              ),
                                              active: i ==
                                                  controller.activePageIndex,
                                              editing: editing,
                                              onTap: () {
                                                if (editing &&
                                                    i ==
                                                        controller
                                                            .activePageIndex) {
                                                  _openPageEditor(
                                                    context,
                                                    i,
                                                    controller.layout.pages[i],
                                                  );
                                                } else {
                                                  controller.selectPage(i);
                                                }
                                              },
                                              onLongPress: editing
                                                  ? () => _openPageEditor(
                                                        context,
                                                        i,
                                                        controller
                                                            .layout.pages[i],
                                                      )
                                                  : null,
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          if (editing)
                                            _PageTabChip(
                                              title: l10n.btnAddPage,
                                              color: LcarsColors.skyBlue,
                                              active: true,
                                              editing: false,
                                              onTap: () => _openPageEditor(
                                                context,
                                                null,
                                                null,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final cols = constraints.maxWidth > 720
                                            ? 4
                                            : (constraints.maxWidth > 460
                                                ? 3
                                                : 2);
                                        final blocks =
                                            controller.activePage.blocks;

                                        return GridView.builder(
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: cols,
                                            mainAxisSpacing: 10,
                                            crossAxisSpacing: 10,
                                            childAspectRatio: 1.55,
                                          ),
                                          itemCount: blocks.length,
                                          itemBuilder: (context, index) {
                                            final blk = blocks[index];
                                            return _buildGridBlock(
                                              context,
                                              blk,
                                              index,
                                              cols,
                                              blocks.length,
                                              pulse,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (visualAlarm)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: redAlertPulse.withValues(
                            alpha: 0.45 + 0.5 * pulse,
                          ),
                          width: 6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: redAlertPulse.withValues(
                              alpha: 0.12 + 0.22 * pulse,
                            ),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridBlock(
    BuildContext context,
    LcarsBlockConfig blk,
    int index,
    int cols,
    int totalCount,
    double alarmPulse,
  ) {
    final editing = controller.blueprintMode;
    final color = LcarsColors.fromToken(blk.colorToken);

    Widget blockWidget;
    if (blk.blockType == LcarsBlockType.action) {
      blockWidget = LcarsButton(
        label: blk.label,
        code: blk.isLocalAction ? 'DEV-${100 + index}' : '47-${100 + index}',
        color: color,
        offline: blk.dependsOnPc && !controller.isPcOnline,
        confirmed: controller.confirmedActionId == blk.actionId,
        blueprintMode: editing,
        onPressed: () {
          if (editing) {
            _openBlockEditor(context, blk);
          } else if (blk.actionId != null) {
            unawaited(controller.executeAction(blk.actionId!));
          }
        },
        onLongPress: () {
          if (!editing) controller.toggleBlueprintMode();
          _openBlockEditor(context, blk);
        },
      );
    } else {
      // Painel de Informação (Read-Only): PC (telemetria/comando), HTTP REST ou Local
      final isPcMetric = blk.source == InfoSource.pcTelemetry;
      final isCommandOutput =
          blk.metricKey != null && blk.metricKey!.startsWith('cmd:');
      final isHttpPanel =
          blk.metricKey != null && blk.metricKey!.startsWith('http:');
      final resolved = _resolveInfoMetric(blk);

      final isBlockAlarm = controller.activeAlarmBlockIds.contains(blk.id) &&
          (blk.alarmMode == 'visual' || blk.alarmMode == 'both');

      blockWidget = LcarsInfoPanel(
        label: blk.label,
        value: resolved.value,
        progress: resolved.progress,
        displayFormat: blk.displayFormat,
        history: controller.historyFor(blk.metricKey),
        alarmActive: isBlockAlarm,
        alarmPulse: isBlockAlarm ? alarmPulse : 0.0,
        sourceTag: isHttpPanel
            ? 'HTTP'
            : (isCommandOutput ? 'CMD' : (isPcMetric ? 'PC' : 'LOCAL')),
        color: color,
        offline: isPcMetric && !controller.isPcOnline,
        blueprintMode: editing,
        onTap: editing
            ? () => _openBlockEditor(context, blk)
            : (isHttpPanel
                ? () => unawaited(controller.refreshSingleHttpPanel(blk))
                : (isCommandOutput
                    ? () => unawaited(
                          controller.executeAction(blk.metricKey!.substring(4)),
                        )
                    : null)),
        onLongPress: () {
          if (!editing) controller.toggleBlueprintMode();
          _openBlockEditor(context, blk);
        },
      );
    }

    if (!editing) return blockWidget;

    final canLeft = index > 0;
    final canRight = index < totalCount - 1;
    final canUp = index - cols >= 0;
    final canDown = index + cols < totalCount;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        unawaited(controller.reorderBlock(details.data, index));
      },
      builder: (context, candidateData, _) {
        final isHovering = candidateData.isNotEmpty;
        return Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(width: 180, height: 110, child: blockWidget),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: blockWidget),
          child: Container(
            decoration: isHovering
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: LcarsColors.amber, width: 3),
                  )
                : null,
            child: Stack(
              children: [
                Positioned.fill(child: blockWidget),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MoveArrowChip(
                        symbol: '◄',
                        enabled: canLeft,
                        onTap: () =>
                            unawaited(controller.moveBlockByDelta(index, -1)),
                      ),
                      const SizedBox(width: 3),
                      _MoveArrowChip(
                        symbol: '▲',
                        enabled: canUp,
                        onTap: () => unawaited(
                            controller.moveBlockByDelta(index, -cols)),
                      ),
                      const SizedBox(width: 3),
                      _MoveArrowChip(
                        symbol: '▼',
                        enabled: canDown,
                        onTap: () => unawaited(
                            controller.moveBlockByDelta(index, cols)),
                      ),
                      const SizedBox(width: 3),
                      _MoveArrowChip(
                        symbol: '►',
                        enabled: canRight,
                        onTap: () =>
                            unawaited(controller.moveBlockByDelta(index, 1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ({String value, double? progress}) _resolveInfoMetric(LcarsBlockConfig blk) {
    final metricKey = blk.metricKey;
    if (metricKey != null && metricKey.startsWith('http:')) {
      final output = controller.httpOutputs[blk.id];
      return (value: output ?? 'TOQUE P/ ATUALIZAR', progress: null);
    }
    if (metricKey != null && metricKey.startsWith('cmd:')) {
      final actionId = metricKey.substring(4);
      final output = controller.commandOutputs[actionId];
      return (value: output ?? 'AGUARDANDO...', progress: null);
    }
    final t = controller.telemetry;
    return switch (metricKey) {
      'cpu.usage_percent' => (
          value: '${t.cpuPercent.toStringAsFixed(1)}%',
          progress: t.cpuPercent / 100.0,
        ),
      'memory.free_gb' => (
          value: '${t.memoryFreeGb.toStringAsFixed(1)} GB',
          progress: t.memoryPercent / 100.0,
        ),
      'temperature.cpu_celsius' => (
          value: t.cpuTempCelsius != null
              ? '${t.cpuTempCelsius!.toStringAsFixed(0)}°C'
              : 'N/A',
          progress:
              t.cpuTempCelsius != null ? (t.cpuTempCelsius! / 100.0) : null,
        ),
      'stardate' => (value: controller.stardateFormatted, progress: null),
      'clock' => (value: controller.clockFormatted, progress: null),
      'battery_level' => (
          value: '${controller.batteryLevel}%',
          progress: controller.batteryLevel / 100.0,
        ),
      _ => (value: '--', progress: null),
    };
  }

  Future<void> _openBlockEditor(
    BuildContext context,
    LcarsBlockConfig? existing,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _BlueprintBlockDialog(
        controller: controller,
        existing: existing,
      ),
    );
  }

  Future<void> _openBackupDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _BackupRestoreDialog(controller: controller),
    );
  }

  Future<void> _openPageEditor(
    BuildContext context,
    int? pageIndex,
    LcarsPageConfig? existing,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PageEditorDialog(
        controller: controller,
        pageIndex: pageIndex,
        existing: existing,
      ),
    );
  }
}

class _PageTabChip extends StatelessWidget {
  final String title;
  final Color color;
  final bool active;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PageTabChip({
    required this.title,
    required this.color,
    required this.active,
    required this.editing,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Text(
          editing && active
              ? '${title.toUpperCase()} ✎'
              : title.toUpperCase(),
          style: TextStyle(
            color: active ? Colors.black : LcarsColors.textLight,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
      ),
    );
  }
}

class _PageEditorDialog extends StatefulWidget {
  final LcarsController controller;
  final int? pageIndex;
  final LcarsPageConfig? existing;

  const _PageEditorDialog({
    required this.controller,
    required this.pageIndex,
    required this.existing,
  });

  @override
  State<_PageEditorDialog> createState() => _PageEditorDialogState();
}

class _PageEditorDialogState extends State<_PageEditorDialog> {
  late TextEditingController _titleCtrl;
  late String _colorToken;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _colorToken = widget.existing?.accentColor ?? 'lavender';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canDelete = widget.pageIndex != null &&
        widget.controller.layout.pages.length > 1;

    return AlertDialog(
      backgroundColor: const Color(0xFF111116),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: LcarsColors.skyBlue, width: 2),
      ),
      title: Text(
        widget.existing == null
            ? l10n.dialogNewPageTitle
            : l10n.dialogEditPageTitle,
        style: const TextStyle(color: LcarsColors.amber, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
            decoration: InputDecoration(
              labelText: l10n.fieldPageTitle,
              hintText: 'DECK 02 • MEDIA',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _colorToken,
            dropdownColor: const Color(0xFF1A1A22),
            style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
            decoration: InputDecoration(labelText: l10n.fieldLcarsColor),
            items: const [
              DropdownMenuItem(value: 'amber', child: Text('Amber (#FF9900)')),
              DropdownMenuItem(value: 'lavender', child: Text('Lavender (#CC99CC)')),
              DropdownMenuItem(value: 'cyan', child: Text('Sky Blue (#9999FF)')),
              DropdownMenuItem(value: 'peach', child: Text('Peach (#FFAA66)')),
              DropdownMenuItem(value: 'gold', child: Text('Gold (#FFCC66)')),
              DropdownMenuItem(value: 'red_alert', child: Text('Red Alert (#CC6666)')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _colorToken = v);
            },
          ),
        ],
      ),
      actions: [
        if (canDelete)
          TextButton(
            onPressed: () {
              unawaited(widget.controller.removePage(widget.pageIndex!));
              Navigator.of(context).pop();
            },
            child: Text(
              l10n.btnRemove,
              style: const TextStyle(color: LcarsColors.redAlert),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.btnCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LcarsColors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            if (widget.pageIndex == null) {
              unawaited(
                widget.controller.addPage(
                  title: _titleCtrl.text,
                  accentColor: _colorToken,
                ),
              );
            } else {
              unawaited(
                widget.controller.updatePage(
                  widget.pageIndex!,
                  title: _titleCtrl.text,
                  accentColor: _colorToken,
                ),
              );
            }
            Navigator.of(context).pop();
          },
          child: Text(l10n.btnSavePage),
        ),
      ],
    );
  }
}

class _MoveArrowChip extends StatelessWidget {
  final String symbol;
  final bool enabled;
  final VoidCallback onTap;

  const _MoveArrowChip({
    required this.symbol,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.black.withValues(alpha: 0.78)
              : Colors.black.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled
                ? LcarsColors.skyBlue
                : LcarsColors.offlineGrey.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          symbol,
          style: TextStyle(
            color: enabled
                ? LcarsColors.skyBlue
                : LcarsColors.textLight.withValues(alpha: 0.25),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SideBarTile extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SideBarTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: double.infinity,
        padding: const EdgeInsets.only(right: 8, bottom: 6),
        color: color,
        alignment: Alignment.bottomRight,
        child: Text(
          label,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

enum _EditorBlockKind { pcAction, info, httpJson, localApp, localControl }

class _BlueprintBlockDialog extends StatefulWidget {
  final LcarsController controller;
  final LcarsBlockConfig? existing;

  const _BlueprintBlockDialog({
    required this.controller,
    required this.existing,
  });

  @override
  State<_BlueprintBlockDialog> createState() => _BlueprintBlockDialogState();
}

class _BlueprintBlockDialogState extends State<_BlueprintBlockDialog> {
  late _EditorBlockKind _kind;
  late InfoSource _infoSource;
  late String _colorToken;
  late TextEditingController _labelCtrl;
  late TextEditingController _httpUrlCtrl;
  late TextEditingController _httpPathCtrl;
  late TextEditingController _httpPrefixCtrl;
  late TextEditingController _httpSuffixCtrl;
  String? _httpPreview;
  bool _testingHttp = false;
  String? _selectedActionId;
  String _selectedMetricKey = 'cpu.usage_percent';
  String _displayFormat = 'bar';
  String _alarmMode = 'none';
  late TextEditingController _alarmMinCtrl;
  late TextEditingController _alarmMaxCtrl;
  String? _selectedAppPackage;
  String _selectedControlKey = kLocalDeviceControls.keys.first;
  List<InstalledApp> _installedApps = const [];
  bool _loadingApps = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final existingHttp = HttpPanelConfig.tryParseMetricKey(e?.metricKey);
    if (e == null) {
      _kind = _EditorBlockKind.pcAction;
    } else if (existingHttp != null) {
      _kind = _EditorBlockKind.httpJson;
    } else if (e.isLocalAppAction) {
      _kind = _EditorBlockKind.localApp;
      _selectedAppPackage = e.actionId!.substring('local_app:'.length);
    } else if (e.isLocalControlAction) {
      _kind = _EditorBlockKind.localControl;
      _selectedControlKey = e.actionId!.substring('local_ctrl:'.length);
      if (!kLocalDeviceControls.containsKey(_selectedControlKey)) {
        _selectedControlKey = kLocalDeviceControls.keys.first;
      }
    } else if (e.blockType == LcarsBlockType.info) {
      _kind = _EditorBlockKind.info;
    } else {
      _kind = _EditorBlockKind.pcAction;
    }

    _infoSource = e?.source ?? InfoSource.pcTelemetry;
    _colorToken = e?.colorToken ?? 'amber';
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _httpUrlCtrl = TextEditingController(text: existingHttp?.url ?? '');
    _httpPathCtrl = TextEditingController(text: existingHttp?.jsonPath ?? '');
    _httpPrefixCtrl = TextEditingController(text: existingHttp?.prefix ?? '');
    _httpSuffixCtrl = TextEditingController(text: existingHttp?.suffix ?? '');
    _selectedActionId = (e != null && !e.isLocalAction)
        ? e.actionId
        : (widget.controller.availableActions.isNotEmpty
            ? widget.controller.availableActions.first.id
            : null);
    _selectedMetricKey = e?.metricKey ??
        (_infoSource == InfoSource.pcTelemetry ? 'cpu.usage_percent' : 'clock');
    _displayFormat = e?.displayFormat ?? 'bar';
    _alarmMode = e?.alarmMode ?? 'none';
    _alarmMinCtrl = TextEditingController(
      text: e?.alarmMin != null ? e!.alarmMin.toString() : '',
    );
    _alarmMaxCtrl = TextEditingController(
      text: e?.alarmMax != null ? e!.alarmMax.toString() : '',
    );

    unawaited(_loadInstalledApps());
  }

  Future<void> _loadInstalledApps() async {
    final apps = await widget.controller.localDevice.listInstalledApps();
    if (!mounted) return;
    setState(() {
      _installedApps = apps;
      _loadingApps = false;
      if (_selectedAppPackage == null ||
          !apps.any((a) => a.packageName == _selectedAppPackage)) {
        _selectedAppPackage =
            apps.isNotEmpty ? apps.first.packageName : null;
      }
    });
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _httpUrlCtrl.dispose();
    _httpPathCtrl.dispose();
    _httpPrefixCtrl.dispose();
    _httpSuffixCtrl.dispose();
    _alarmMinCtrl.dispose();
    _alarmMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _testHttpRequest() async {
    final cfg = HttpPanelConfig(
      url: _httpUrlCtrl.text.trim(),
      jsonPath: _httpPathCtrl.text.trim(),
      prefix: _httpPrefixCtrl.text,
      suffix: _httpSuffixCtrl.text,
    );
    setState(() {
      _testingHttp = true;
      _httpPreview = 'CONSULTANDO...';
    });
    try {
      final res = await widget.controller.httpPanelService.fetchValue(cfg);
      if (mounted) setState(() => _httpPreview = 'RESULTADO: $res');
    } catch (err) {
      if (mounted) setState(() => _httpPreview = 'ERRO: $err');
    } finally {
      if (mounted) setState(() => _testingHttp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localizedControls = <String, String>{
      'volume_up': l10n.ctrlVolumeUp,
      'volume_down': l10n.ctrlVolumeDown,
      'volume_mute': l10n.ctrlVolumeMute,
      'brightness_up': l10n.ctrlBrightnessUp,
      'brightness_down': l10n.ctrlBrightnessDown,
      'brightness_auto': l10n.ctrlBrightnessAuto,
      'bluetooth': l10n.ctrlBluetooth,
      'wifi_panel': l10n.ctrlWifiPanel,
    };
    final pcMetricsLocalized = <String, String>{
      'cpu.usage_percent': l10n.metricPcCpu,
      'memory.free_gb': l10n.metricPcRamFree,
      'temperature.cpu_celsius': l10n.metricPcTemp,
    };
    final localMetricsLocalized = <String, String>{
      'clock': l10n.metricLocalClock,
      'stardate': l10n.metricLocalStardate,
      'battery_level': l10n.metricLocalBattery,
    };

    final actions = widget.controller.availableActions;
    final hasSelectedAction =
        _selectedActionId != null && actions.any((a) => a.id == _selectedActionId);
    final safeActionId = hasSelectedAction
        ? _selectedActionId
        : (actions.isNotEmpty ? actions.first.id : null);
    _selectedActionId = safeActionId;

    final safeAppPackage = (_selectedAppPackage != null &&
            _installedApps.any((a) => a.packageName == _selectedAppPackage))
        ? _selectedAppPackage
        : (_installedApps.isNotEmpty ? _installedApps.first.packageName : null);
    _selectedAppPackage = safeAppPackage;

    final pcMetricsWithCommands = <String, String>{
      ...pcMetricsLocalized,
      for (final a in actions.where((a) => a.commandType == 'shell'))
        'cmd:${a.id}': 'PC CMD: ${a.name} (${a.id})',
    };
    final metricsMap = _infoSource == InfoSource.pcTelemetry
        ? pcMetricsWithCommands
        : localMetricsLocalized;
    if (!metricsMap.containsKey(_selectedMetricKey)) {
      _selectedMetricKey = metricsMap.keys.first;
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF111116),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: LcarsColors.skyBlue, width: 2),
      ),
      title: Text(
        widget.existing == null
            ? l10n.dialogNewBlockTitle
            : l10n.dialogEditBlockTitle,
        style: const TextStyle(color: LcarsColors.amber, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<_EditorBlockKind>(
              initialValue: _kind,
              dropdownColor: const Color(0xFF1A1A22),
              style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
              decoration: InputDecoration(labelText: l10n.fieldBlockType),
              items: [
                DropdownMenuItem(
                  value: _EditorBlockKind.pcAction,
                  child: Text(l10n.blockTypePcAction),
                ),
                DropdownMenuItem(
                  value: _EditorBlockKind.localApp,
                  child: Text(l10n.blockTypeLocalApp),
                ),
                DropdownMenuItem(
                  value: _EditorBlockKind.localControl,
                  child: Text(l10n.blockTypeLocalControl),
                ),
                DropdownMenuItem(
                  value: _EditorBlockKind.info,
                  child: Text(l10n.blockTypeInfo),
                ),
                DropdownMenuItem(
                  value: _EditorBlockKind.httpJson,
                  child: Text(l10n.blockTypeHttpJson),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _kind = v);
              },
            ),
            const SizedBox(height: 12),
            if (_kind == _EditorBlockKind.pcAction)
              DropdownButtonFormField<String>(
                key: ValueKey(safeActionId),
                initialValue: safeActionId,
                dropdownColor: const Color(0xFF1A1A22),
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 15),
                decoration: InputDecoration(labelText: l10n.fieldPcAction),
                items: actions
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.name} (${a.category})'),
                      ),
                    )
                    .toList(),
                onChanged: actions.isEmpty
                    ? null
                    : (v) {
                        setState(() {
                          _selectedActionId = v;
                          final match =
                              actions.where((a) => a.id == v).firstOrNull;
                          if (match != null && _labelCtrl.text.isEmpty) {
                            _labelCtrl.text = match.name;
                          }
                        });
                      },
              )
            else if (_kind == _EditorBlockKind.localApp) ...[
              if (_loadingApps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.loadingApps,
                    style: const TextStyle(
                        color: LcarsColors.skyBlue, fontSize: 12),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey(safeAppPackage),
                  initialValue: safeAppPackage,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A22),
                  style: const TextStyle(
                      color: LcarsColors.textLight, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: l10n.fieldInstalledApp,
                  ),
                  items: _installedApps
                      .map(
                        (app) => DropdownMenuItem(
                          value: app.packageName,
                          child: Text(
                            app.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _installedApps.isEmpty
                      ? null
                      : (pkg) {
                          setState(() {
                            _selectedAppPackage = pkg;
                            final match = _installedApps
                                .where((a) => a.packageName == pkg)
                                .firstOrNull;
                            if (match != null && _labelCtrl.text.isEmpty) {
                              _labelCtrl.text = match.name;
                            }
                          });
                        },
                ),
            ] else if (_kind == _EditorBlockKind.httpJson) ...[
              TextField(
                controller: _httpUrlCtrl,
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.fieldHttpUrl,
                  hintText: 'https://economia.awesomeapi.com.br/json/last/USD-BRL',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _httpPathCtrl,
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 14),
                decoration: InputDecoration(
                  labelText: l10n.fieldHttpPath,
                  hintText: 'USDBRL.bid',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _httpPrefixCtrl,
                      style: const TextStyle(
                          color: LcarsColors.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l10n.fieldHttpPrefix,
                        hintText: 'R\$ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _httpSuffixCtrl,
                      style: const TextStyle(
                          color: LcarsColors.textLight, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l10n.fieldHttpSuffix,
                        hintText: '°C',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LcarsColors.skyBlue,
                  side: const BorderSide(color: LcarsColors.skyBlue),
                ),
                onPressed: _testingHttp ? null : _testHttpRequest,
                child: Text(
                  _testingHttp
                      ? l10n.testingRequestButton
                      : l10n.testRequestButton,
                ),
              ),
              if (_httpPreview != null) ...[
                const SizedBox(height: 6),
                Text(
                  _httpPreview!,
                  style: const TextStyle(
                    color: LcarsColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ] else if (_kind == _EditorBlockKind.localControl)
              DropdownButtonFormField<String>(
                initialValue: _selectedControlKey,
                dropdownColor: const Color(0xFF1A1A22),
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 15),
                decoration:
                    InputDecoration(labelText: l10n.fieldDeviceControl),
                items: localizedControls.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedControlKey = v;
                    if (_labelCtrl.text.isEmpty) {
                      _labelCtrl.text = localizedControls[v] ?? v;
                    }
                  });
                },
              )
            else ...[
              DropdownButtonFormField<InfoSource>(
                initialValue: _infoSource,
                dropdownColor: const Color(0xFF1A1A22),
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 15),
                decoration: InputDecoration(labelText: l10n.fieldDataSource),
                items: [
                  DropdownMenuItem(
                    value: InfoSource.pcTelemetry,
                    child: Text(l10n.sourcePcTelemetry),
                  ),
                  DropdownMenuItem(
                    value: InfoSource.localDevice,
                    child: Text(l10n.sourceLocalDevice),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _infoSource = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedMetricKey,
                dropdownColor: const Color(0xFF1A1A22),
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 15),
                decoration: InputDecoration(labelText: l10n.fieldMetric),
                items: metricsMap.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMetricKey = v);
                },
              ),
              if (const {
                'cpu.usage_percent',
                'memory.free_gb',
                'temperature.cpu_celsius',
                'battery_level',
              }.contains(_selectedMetricKey)) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: const {'bar', 'sparkline', 'gauge', 'value'}
                          .contains(_displayFormat)
                      ? _displayFormat
                      : 'bar',
                  dropdownColor: const Color(0xFF1A1A22),
                  style: const TextStyle(
                      color: LcarsColors.textLight, fontSize: 15),
                  decoration:
                      InputDecoration(labelText: l10n.fieldDisplayFormat),
                  items: [
                    DropdownMenuItem(
                      value: 'bar',
                      child: Text(l10n.formatBar),
                    ),
                    DropdownMenuItem(
                      value: 'sparkline',
                      child: Text(l10n.formatSparkline),
                    ),
                    DropdownMenuItem(
                      value: 'gauge',
                      child: Text(l10n.formatGauge),
                    ),
                    DropdownMenuItem(
                      value: 'value',
                      child: Text(l10n.formatValue),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _displayFormat = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      const {'none', 'visual', 'sound', 'both'}.contains(_alarmMode)
                          ? _alarmMode
                          : 'none',
                  dropdownColor: const Color(0xFF1A1A22),
                  style: const TextStyle(
                      color: LcarsColors.textLight, fontSize: 15),
                  decoration: InputDecoration(labelText: l10n.fieldAlarmMode),
                  items: [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(l10n.alarmNone),
                    ),
                    DropdownMenuItem(
                      value: 'visual',
                      child: Text(l10n.alarmVisual),
                    ),
                    DropdownMenuItem(
                      value: 'sound',
                      child: Text(l10n.alarmSound),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text(l10n.alarmBoth),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _alarmMode = v);
                  },
                ),
                if (_alarmMode != 'none') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _alarmMinCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              color: LcarsColors.textLight, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.fieldAlarmMin,
                            hintText: 'Ex.: 15',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _alarmMaxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              color: LcarsColors.textLight, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.fieldAlarmMax,
                            hintText: 'Ex.: 85',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
              decoration: InputDecoration(labelText: l10n.fieldPanelLabel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _colorToken,
              dropdownColor: const Color(0xFF1A1A22),
              style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
              decoration: InputDecoration(labelText: l10n.fieldLcarsColor),
              items: const [
                DropdownMenuItem(value: 'amber', child: Text('Amber (#FF9900)')),
                DropdownMenuItem(value: 'lavender', child: Text('Lavender (#CC99CC)')),
                DropdownMenuItem(value: 'cyan', child: Text('Sky Blue (#9999FF)')),
                DropdownMenuItem(value: 'peach', child: Text('Peach (#FFAA66)')),
                DropdownMenuItem(value: 'gold', child: Text('Gold (#FFCC66)')),
                DropdownMenuItem(value: 'red_alert', child: Text('Red Alert (#CC6666)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _colorToken = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () {
              unawaited(widget.controller.removeBlock(widget.existing!.id));
              Navigator.of(context).pop();
            },
            child: Text(
              l10n.btnRemove,
              style: const TextStyle(color: LcarsColors.redAlert),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.btnCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LcarsColors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            final defaultLabel = switch (_kind) {
              _EditorBlockKind.pcAction => 'PC ACTION',
              _EditorBlockKind.localApp => _installedApps
                      .where((a) => a.packageName == _selectedAppPackage)
                      .firstOrNull
                      ?.name ??
                  'APP',
              _EditorBlockKind.localControl =>
                localizedControls[_selectedControlKey] ?? 'CONTROL',
              _EditorBlockKind.httpJson => 'REST JSON',
              _EditorBlockKind.info => 'SENSOR',
            };
            final label = _labelCtrl.text.trim().isEmpty
                ? defaultLabel
                : _labelCtrl.text.trim();

            final resolvedActionId = switch (_kind) {
              _EditorBlockKind.pcAction => _selectedActionId,
              _EditorBlockKind.localApp => _selectedAppPackage != null
                  ? 'local_app:$_selectedAppPackage'
                  : null,
              _EditorBlockKind.localControl =>
                'local_ctrl:$_selectedControlKey',
              _EditorBlockKind.info || _EditorBlockKind.httpJson => null,
            };

            final isInfoBlock =
                _kind == _EditorBlockKind.info || _kind == _EditorBlockKind.httpJson;
            final resolvedSource = _kind == _EditorBlockKind.httpJson
                ? InfoSource.localDevice
                : (_kind == _EditorBlockKind.info ? _infoSource : null);
            final resolvedMetricKey = _kind == _EditorBlockKind.httpJson
                ? HttpPanelConfig(
                    url: _httpUrlCtrl.text.trim(),
                    jsonPath: _httpPathCtrl.text.trim(),
                    prefix: _httpPrefixCtrl.text,
                    suffix: _httpSuffixCtrl.text,
                  ).toMetricKey()
                : (_kind == _EditorBlockKind.info ? _selectedMetricKey : null);

            final parsedMin = double.tryParse(
                _alarmMinCtrl.text.trim().replaceAll(',', '.'));
            final parsedMax = double.tryParse(
                _alarmMaxCtrl.text.trim().replaceAll(',', '.'));

            final block = LcarsBlockConfig(
              id: widget.existing?.id ??
                  'blk_${const Uuid().v4().substring(0, 8)}',
              blockType:
                  isInfoBlock ? LcarsBlockType.info : LcarsBlockType.action,
              label: label,
              colorToken: _colorToken,
              actionId: resolvedActionId,
              source: resolvedSource,
              metricKey: resolvedMetricKey,
              displayFormat:
                  _kind == _EditorBlockKind.info ? _displayFormat : 'bar',
              alarmMode: _kind == _EditorBlockKind.info ? _alarmMode : 'none',
              alarmMin: _kind == _EditorBlockKind.info && _alarmMode != 'none'
                  ? parsedMin
                  : null,
              alarmMax: _kind == _EditorBlockKind.info && _alarmMode != 'none'
                  ? parsedMax
                  : null,
            );
            unawaited(widget.controller.addOrUpdateBlock(block));
            Navigator.of(context).pop();
          },
          child: Text(l10n.btnSaveSync),
        ),
      ],
    );
  }
}

class _BackupRestoreDialog extends StatefulWidget {
  final LcarsController controller;

  const _BackupRestoreDialog({required this.controller});

  @override
  State<_BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<_BackupRestoreDialog> {
  final _jsonCtrl = TextEditingController();
  String? _feedbackMsg;
  bool _isError = false;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveToFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final json = widget.controller.exportBackupJson();
      final saved = await widget.controller.localDevice.saveBackupFile(json);
      if (!mounted) return;
      setState(() {
        _isError = false;
        _feedbackMsg = saved ? l10n.backupSavedOk : l10n.backupCancelled;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _feedbackMsg = '$err';
      });
    }
  }

  Future<void> _copyToClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    final json = widget.controller.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    setState(() {
      _isError = false;
      _feedbackMsg = l10n.backupCopiedOk;
    });
  }

  Future<void> _openFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final content = await widget.controller.localDevice.openBackupFile();
      if (content == null || content.trim().isEmpty) return;
      await widget.controller.importBackupJson(content);
      if (!mounted) return;
      setState(() {
        _isError = false;
        _feedbackMsg = l10n.backupRestoredOk;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _feedbackMsg = '${l10n.backupInvalidError}: $err';
      });
    }
  }

  Future<void> _restoreFromText() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) return;
    try {
      await widget.controller.importBackupJson(raw);
      if (!mounted) return;
      setState(() {
        _isError = false;
        _feedbackMsg = l10n.backupRestoredOk;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _feedbackMsg = '${l10n.backupInvalidError}: $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pcOnline = widget.controller.isPcOnline;

    return AlertDialog(
      backgroundColor: const Color(0xFF111116),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: LcarsColors.lavender, width: 2),
      ),
      title: Text(
        l10n.backupDialogTitle,
        style: const TextStyle(color: LcarsColors.amber, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LcarsColors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saveToFile,
                  child: Text(l10n.btnExportFile),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LcarsColors.gold,
                    side: const BorderSide(color: LcarsColors.gold),
                  ),
                  onPressed: _copyToClipboard,
                  child: Text(l10n.btnCopyJson),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LcarsColors.skyBlue,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _openFromFile,
                  child: Text(l10n.btnImportFile),
                ),
              ],
            ),
            if (pcOnline) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LcarsColors.lavender,
                      side: const BorderSide(color: LcarsColors.lavender),
                    ),
                    onPressed: () {
                      unawaited(widget.controller.pushLayoutBackupToPc());
                      setState(() {
                        _isError = false;
                        _feedbackMsg = l10n.backupPushedPc;
                      });
                    },
                    child: Text(l10n.btnPushPc),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LcarsColors.peach,
                      side: const BorderSide(color: LcarsColors.peach),
                    ),
                    onPressed: () {
                      unawaited(widget.controller.pullLayoutBackupFromPc());
                      setState(() {
                        _isError = false;
                        _feedbackMsg = l10n.backupPulledPc;
                      });
                    },
                    child: Text(l10n.btnPullPc),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _jsonCtrl,
              maxLines: 4,
              style: const TextStyle(color: LcarsColors.textLight, fontSize: 12),
              decoration: InputDecoration(
                labelText: l10n.fieldPasteBackupJson,
                hintText: '{"schema": "lcars_mobile_backup_v1", ...}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: LcarsColors.amber,
                side: const BorderSide(color: LcarsColors.amber),
              ),
              onPressed: _restoreFromText,
              child: Text(l10n.btnRestoreJsonText),
            ),
            if (_feedbackMsg != null) ...[
              const SizedBox(height: 10),
              Text(
                _feedbackMsg!,
                style: TextStyle(
                  color: _isError ? LcarsColors.redAlert : LcarsColors.skyBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.sideDone),
        ),
      ],
    );
  }
}
