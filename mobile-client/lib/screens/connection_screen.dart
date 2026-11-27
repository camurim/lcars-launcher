import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../protocol/lcars_protocol.dart';
import '../services/lcars_controller.dart';
import '../services/lcars_transport.dart';
import '../theme/lcars_theme.dart';
import '../widgets/lcars_elbow.dart';
import '../widgets/lcars_pill_bar.dart';

class ConnectionScreen extends StatefulWidget {
  final LcarsController controller;

  const ConnectionScreen({super.key, required this.controller});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _ipCtrl = TextEditingController(text: '127.0.0.1');
  final _portCtrl = TextEditingController(text: '8765');
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();
  final _mdns = MdnsDiscoveryService();

  List<DiscoveredAgent> _discovered = const [];
  StreamSubscription<List<DiscoveredAgent>>? _mdnsSub;
  bool _connecting = false;
  bool _checkingUsb = false;
  String? _statusMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mdnsSub = _mdns.agents.listen((list) {
      if (mounted) setState(() => _discovered = list);
    });
    unawaited(_mdns.start().catchError((_) {}));
  }

  @override
  void dispose() {
    unawaited(_mdnsSub?.cancel());
    unawaited(_mdns.stop());
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _activateUsbMode() async {
    unawaited(widget.controller.feedback.playTap());
    const usbHost = '127.0.0.1';
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8765;

    setState(() {
      _ipCtrl.text = usbHost;
      _portCtrl.text = port.toString();
      _checkingUsb = true;
      _error = null;
      _statusMessage = 'VERIFICANDO TÚNEL USB EM $usbHost:$port...';
    });
    debugPrint('[LCARS USB] Verificando túnel ADB em $usbHost:$port...');

    try {
      final socket = await Socket.connect(
        usbHost,
        port,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
      debugPrint('[LCARS USB] Túnel USB acessível em $usbHost:$port!');

      if (!mounted) return;
      if (_pinCtrl.text.trim().length == 6) {
        setState(() {
          _checkingUsb = false;
          _statusMessage = 'TÚNEL USB ATIVO! CONECTANDO...';
        });
        await _submitPair();
      } else {
        setState(() {
          _checkingUsb = false;
          _statusMessage =
              'TÚNEL USB ATIVO EM $usbHost:$port! MESMO VIA USB, DIGITE O PIN DE 6 DÍGITOS DO DESKTOP AGENT ABAIXO E TOQUE EM AUTORIZAR.';
        });
        _pinFocus.requestFocus();
      }
    } catch (err) {
      debugPrint('[LCARS USB] Falha ao alcançar $usbHost:$port: $err');
      if (!mounted) return;
      setState(() {
        _checkingUsb = false;
        _statusMessage = null;
        _error =
            'Túnel USB não detectado em $usbHost:$port. No PC, execute:\nadb reverse tcp:$port tcp:$port';
      });
    }
  }

  Future<void> _submitPair() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8765;
    final pin = _pinCtrl.text.trim();
    if (ip.isEmpty || pin.length != 6) {
      setState(() => _error = 'Informe um IP válido e um PIN de 6 dígitos.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
      _statusMessage = 'CONECTANDO A ws://$ip:$port/ws...';
    });
    debugPrint('[LCARS LINK] Conectando a ws://$ip:$port/ws (PIN informado)...');

    try {
      await widget.controller.connectAndPair(
        endpoint: Uri.parse('ws://$ip:$port/ws'),
        pin: pin,
      );
      debugPrint('[LCARS LINK] PAIR_REQUEST enviado com sucesso.');
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      debugPrint('[LCARS LINK] Erro ao conectar em ws://$ip:$port/ws: $err');
      if (mounted) {
        setState(() {
          _statusMessage = null;
          _error = 'Falha ao conectar em ws://$ip:$port/ws: $err';
        });
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.of(context).push<PairingQrPayload>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (result == null) return;
    _ipCtrl.text = result.ip;
    _portCtrl.text = result.port.toString();
    _pinCtrl.text = result.pin;
    await _submitPair();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LcarsElbow(
                    color: LcarsColors.lavender,
                    width: 132,
                    height: 64,
                    label: 'LINK',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LcarsPillBar(
                          color: LcarsColors.amber,
                          label: 'SUBSPACE LINK • PAREAMENTO',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LcarsPillBar(
                                color: LcarsColors.skyBlue,
                                capSide: LcarsCapSide.both,
                                label: 'LER QR CODE',
                                onTap: _openQrScanner,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LcarsPillBar(
                                color: LcarsColors.gold,
                                capSide: LcarsCapSide.both,
                                label: _checkingUsb
                                    ? 'TESTANDO USB...'
                                    : 'MODO USB (127.0.0.1)',
                                onTap: _checkingUsb ? null : _activateUsbMode,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'AGENTES DESCOBERTOS NA REDE (mDNS)',
                      style: TextStyle(
                        color: LcarsColors.skyBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_discovered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: LcarsColors.offlineGrey),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'PROCURANDO _lcars-agent._tcp NA REDE LOCAL...',
                          style: TextStyle(
                            color: LcarsColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      ..._discovered.map(
                        (agent) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: LcarsPillBar(
                            color: LcarsColors.peach,
                            height: 40,
                            capSide: LcarsCapSide.both,
                            label: '${agent.name} (${agent.host}:${agent.port})',
                            onTap: () {
                              _ipCtrl.text = agent.host;
                              _portCtrl.text = agent.port.toString();
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'CONEXÃO MANUAL / PIN DE 6 DÍGITOS',
                      style: TextStyle(
                        color: LcarsColors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: LcarsColors.gold.withValues(alpha: 0.12),
                        border: Border.all(
                          color: LcarsColors.gold,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'IMPORTANTE: MESMO NO MODO USB (127.0.0.1), O PIN DE 6 DÍGITOS EXIBIDO NO DESKTOP AGENT É OBRIGATÓRIO PARA AUTORIZAR O DISPOSITIVO.',
                        style: TextStyle(
                          color: LcarsColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _LcarsTextField(
                            controller: _ipCtrl,
                            label: 'ENDEREÇO IP',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LcarsTextField(
                            controller: _portCtrl,
                            label: 'PORTA',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _LcarsTextField(
                      controller: _pinCtrl,
                      focusNode: _pinFocus,
                      label: 'PIN TEMPORÁRIO (6 DÍGITOS — OBRIGATÓRIO)',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: LcarsColors.skyBlue),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(
                            color: LcarsColors.skyBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: LcarsColors.redAlert,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    LcarsPillBar(
                      color: LcarsColors.amber,
                      height: 44,
                      capSide: LcarsCapSide.both,
                      label: _connecting ? 'CONECTANDO...' : 'AUTORIZAR E CONECTAR',
                      onTap: _connecting ? null : _submitPair,
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
}

class _LcarsTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final TextInputType? keyboardType;
  final int? maxLength;

  const _LcarsTextField({
    required this.controller,
    required this.label,
    this.focusNode,
    this.keyboardType,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(
        color: LcarsColors.textLight,
        fontSize: 16,
        letterSpacing: 1.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: LcarsColors.lavender, fontSize: 12),
        counterText: '',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LcarsColors.amber, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LcarsColors.skyBlue, width: 2),
        ),
      ),
    );
  }
}

class _QrScannerPage extends StatelessWidget {
  const _QrScannerPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('ESCANEAR QR CODE DO DESKTOP AGENT'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final raw = barcode.rawValue;
            if (raw == null) continue;
            try {
              final parsed = PairingQrPayload.parse(raw);
              Navigator.of(context).pop(parsed);
              return;
            } catch (_) {}
          }
        },
      ),
    );
  }
}
