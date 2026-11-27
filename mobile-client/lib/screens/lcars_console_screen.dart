import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../protocol/lcars_protocol.dart';
import '../services/lcars_controller.dart';
import '../theme/lcars_theme.dart';
import '../widgets/lcars_button.dart';
import '../widgets/lcars_elbow.dart';
import '../widgets/lcars_info_panel.dart';
import '../widgets/lcars_pill_bar.dart';
import 'connection_screen.dart';

class LcarsConsoleScreen extends StatelessWidget {
  final LcarsController controller;

  const LcarsConsoleScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pcOnline = controller.isPcOnline;
        final editing = controller.blueprintMode;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Cabeçalho LCARS com cotovelo superior esquerdo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LcarsElbow(
                        color: editing ? LcarsColors.skyBlue : LcarsColors.amber,
                        label: editing ? 'BLUEPRINT' : 'LCARS 47',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LcarsPillBar(
                              color: pcOnline
                                  ? LcarsColors.peach
                                  : LcarsColors.redAlert,
                              label: pcOnline
                                  ? '${controller.layout.profileName} • ONLINE'
                                  : '${controller.layout.profileName} • STANDBY / OFFLINE',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              controller.statusLog.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: LcarsColors.skyBlue,
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
                                label: 'CONECTAR',
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
                                label: controller.keepScreenOn
                                    ? 'TELA ATIVA'
                                    : 'TELA AUTO',
                                color: controller.keepScreenOn
                                    ? LcarsColors.skyBlue
                                    : LcarsColors.offlineGrey,
                                onTap: () => unawaited(
                                  controller.toggleKeepScreenOn(),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _SideBarTile(
                                label: editing ? 'CONCLUIR' : 'EDITAR PAINEL',
                                color: editing
                                    ? LcarsColors.skyBlue
                                    : LcarsColors.gold,
                                onTap: controller.toggleBlueprintMode,
                              ),
                              if (editing) ...[
                                const SizedBox(height: 6),
                                _SideBarTile(
                                  label: '+ BLOCO',
                                  color: LcarsColors.peach,
                                  onTap: () => _openBlockEditor(context, null),
                                ),
                              ],
                              const SizedBox(height: 6),
                              const Expanded(
                                child: LcarsElbow(
                                  color: LcarsColors.amber,
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

                        // Grade Dinâmica
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cols = constraints.maxWidth > 720
                                  ? 4
                                  : (constraints.maxWidth > 460 ? 3 : 2);
                              final blocks = controller.layout.blocks;

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
                                  return _buildGridBlock(context, blk, index);
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
          ),
        );
      },
    );
  }

  Widget _buildGridBlock(
    BuildContext context,
    LcarsBlockConfig blk,
    int index,
  ) {
    final editing = controller.blueprintMode;
    final color = LcarsColors.fromToken(blk.colorToken);

    if (blk.blockType == LcarsBlockType.action) {
      return LcarsButton(
        label: blk.label,
        code: '47-${100 + index}',
        color: color,
        offline: !controller.isPcOnline,
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
    }

    // Painel de Informação (Read-Only): PC (telemetria ou saída de comando) ou Local
    final isPcMetric = blk.source == InfoSource.pcTelemetry;
    final isCommandOutput =
        blk.metricKey != null && blk.metricKey!.startsWith('cmd:');
    final resolved = _resolveInfoMetric(blk.metricKey);

    return LcarsInfoPanel(
      label: blk.label,
      value: resolved.value,
      progress: resolved.progress,
      sourceTag: isCommandOutput ? 'CMD' : (isPcMetric ? 'PC' : 'LOCAL'),
      color: color,
      offline: isPcMetric && !controller.isPcOnline,
      blueprintMode: editing,
      onTap: editing
          ? () => _openBlockEditor(context, blk)
          : (isCommandOutput
              ? () => unawaited(
                    controller.executeAction(blk.metricKey!.substring(4)),
                  )
              : null),
      onLongPress: () {
        if (!editing) controller.toggleBlueprintMode();
        _openBlockEditor(context, blk);
      },
    );
  }

  ({String value, double? progress}) _resolveInfoMetric(String? metricKey) {
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
  late LcarsBlockType _type;
  late InfoSource _infoSource;
  late String _colorToken;
  late TextEditingController _labelCtrl;
  String? _selectedActionId;
  String _selectedMetricKey = 'cpu.usage_percent';

  static const _pcMetrics = <String, String>{
    'cpu.usage_percent': 'PC: Uso de CPU (%)',
    'memory.free_gb': 'PC: RAM Livre (GB)',
    'temperature.cpu_celsius': 'PC: Temperatura CPU (°C)',
  };

  static const _localMetrics = <String, String>{
    'clock': 'Local: Data/Hora',
    'stardate': 'Local: Data Estelar (Stardate)',
    'battery_level': 'Local: Nível de Bateria',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.blockType ?? LcarsBlockType.action;
    _infoSource = e?.source ?? InfoSource.pcTelemetry;
    _colorToken = e?.colorToken ?? 'amber';
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _selectedActionId = e?.actionId ??
        (widget.controller.availableActions.isNotEmpty
            ? widget.controller.availableActions.first.id
            : null);
    _selectedMetricKey = e?.metricKey ??
        (_infoSource == InfoSource.pcTelemetry ? 'cpu.usage_percent' : 'clock');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.controller.availableActions;
    final hasSelectedAction =
        _selectedActionId != null && actions.any((a) => a.id == _selectedActionId);
    final safeActionId = hasSelectedAction
        ? _selectedActionId
        : (actions.isNotEmpty ? actions.first.id : null);
    _selectedActionId = safeActionId;
    final pcMetricsWithCommands = <String, String>{
      ..._pcMetrics,
      for (final a in actions.where((a) => a.commandType == 'shell'))
        'cmd:${a.id}': 'PC Comando: ${a.name} (${a.id})',
    };
    final metricsMap = _infoSource == InfoSource.pcTelemetry
        ? pcMetricsWithCommands
        : _localMetrics;
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
            ? 'BLUEPRINT • NOVO BLOCO'
            : 'BLUEPRINT • EDITAR BLOCO',
        style: const TextStyle(color: LcarsColors.amber, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<LcarsBlockType>(
              initialValue: _type,
              dropdownColor: const Color(0xFF1A1A22),
              style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
              decoration: const InputDecoration(labelText: 'TIPO DE BLOCO'),
              items: const [
                DropdownMenuItem(
                  value: LcarsBlockType.action,
                  child: Text('Painel de Execução (Ação do PC)'),
                ),
                DropdownMenuItem(
                  value: LcarsBlockType.info,
                  child: Text('Painel de Informação (Read-Only)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            if (_type == LcarsBlockType.action)
              DropdownButtonFormField<String>(
                key: ValueKey(safeActionId),
                initialValue: safeActionId,
                dropdownColor: const Color(0xFF1A1A22),
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 15),
                decoration:
                    const InputDecoration(labelText: 'AÇÃO SINCRONIZADA DO PC'),
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
            else ...[
              DropdownButtonFormField<InfoSource>(
                initialValue: _infoSource,
                dropdownColor: const Color(0xFF1A1A22),
                style:
                    const TextStyle(color: LcarsColors.textLight, fontSize: 15),
                decoration: const InputDecoration(labelText: 'FONTE DE DADOS'),
                items: const [
                  DropdownMenuItem(
                    value: InfoSource.pcTelemetry,
                    child: Text('Telemetria do PC'),
                  ),
                  DropdownMenuItem(
                    value: InfoSource.localDevice,
                    child: Text('Sensor Local do Tablet'),
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
                decoration: const InputDecoration(labelText: 'MÉTRICA'),
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
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
              decoration: const InputDecoration(labelText: 'RÓTULO NO PAINEL'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _colorToken,
              dropdownColor: const Color(0xFF1A1A22),
              style: const TextStyle(color: LcarsColors.textLight, fontSize: 15),
              decoration: const InputDecoration(labelText: 'COR LCARS'),
              items: const [
                DropdownMenuItem(value: 'amber', child: Text('Amber (#FF9900)')),
                DropdownMenuItem(value: 'lavender', child: Text('Lilás (#CC99CC)')),
                DropdownMenuItem(value: 'cyan', child: Text('Azul-Celeste (#9999FF)')),
                DropdownMenuItem(value: 'peach', child: Text('Pêssego (#FFAA66)')),
                DropdownMenuItem(value: 'gold', child: Text('Dourado (#FFCC66)')),
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
            child: const Text(
              'REMOVER',
              style: TextStyle(color: LcarsColors.redAlert),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LcarsColors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            final label = _labelCtrl.text.trim().isEmpty
                ? (_type == LcarsBlockType.action ? 'AÇÃO' : 'SENSOR')
                : _labelCtrl.text.trim();
            final block = LcarsBlockConfig(
              id: widget.existing?.id ?? 'blk_${const Uuid().v4().substring(0, 8)}',
              blockType: _type,
              label: label,
              colorToken: _colorToken,
              actionId: _type == LcarsBlockType.action ? _selectedActionId : null,
              source: _type == LcarsBlockType.info ? _infoSource : null,
              metricKey:
                  _type == LcarsBlockType.info ? _selectedMetricKey : null,
            );
            unawaited(widget.controller.addOrUpdateBlock(block));
            Navigator.of(context).pop();
          },
          child: const Text('SALVAR E SINCRONIZAR'),
        ),
      ],
    );
  }
}
