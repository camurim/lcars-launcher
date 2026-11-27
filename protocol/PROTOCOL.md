# LCARS Launcher Communication Protocol (v1.0)

Este documento define o protocolo bidirecional de comunicação entre o **Desktop Agent** (servidor/daemon em Rust/Tauri v2 rodando em Windows/Linux) e o **Mobile Client** (aplicativo Flutter inspirado na interface LCARS).

---

## 1. Visão Geral e Transportes

O protocolo é **agnóstico ao transporte** e utiliza mensagens JSON UTF-8 encapsuladas em um envelope comum.

| Transporte | Uso Principal | Framing / Delimitação | Porta / UUID Padrão |
| :--- | :--- | :--- | :--- |
| **WebSocket (Wi-Fi LAN)** | Operação principal em rede local | Frame WebSocket Text (`0x01`) | `ws://<host>:8765/ws` (mDNS `_lcars._tcp.local`) |
| **WebSocket sobre USB** | Baixa latência sem Wi-Fi (via `adb reverse` / `iproxy`) | Frame WebSocket Text (`0x01`) | `ws://127.0.0.1:8765/ws` |
| **Bluetooth Classic (RFCOMM / Serial)** | Conexão direta sem rede | NDJSON (`\n`-delimited UTF-8 JSON) | SPP UUID `00001101-0000-1000-8000-00805F9B34FB` |
| **Bluetooth Low Energy (BLE GATT)** | Conexão de baixo consumo | Chunking com cabeçalho de 3 bytes (`[flags:1][seq:1][len:1]`) + payload JSON recombinado | Service UUID `7E1A0001-4C43-4152-5300-000000000001` |

### 1.1. BLE GATT Characteristics (quando via BLE)
- **TX Characteristic (PC → Mobile, Notify):** `7E1A0002-4C43-4152-5300-000000000001`
- **RX Characteristic (Mobile → PC, Write Without Response / Write):** `7E1A0003-4C43-4152-5300-000000000001`
- **MTU Alvo:** negociação para `>= 185` bytes (fallback seguro para 20 bytes com fragmentação via `flags`: `0x01` = START, `0x02` = CONTINUATION, `0x04` = END, `0x05` = SINGLE_FRAME).

---

## 2. Envelope Padrão de Mensagem

Todas as mensagens trafegadas em qualquer transporte seguem o envelope definido em [`schemas/envelope.schema.json`](./schemas/envelope.schema.json):

```json
{
  "version": "1.0",
  "type": "TELEMETRY",
  "timestamp": "2026-11-27T11:20:00.123Z",
  "req_id": "550e8400-e29b-41d4-a716-446655440000",
  "token": "lcars_tok_live_...",
  "payload": {}
}
```

### Campos do Envelope
- `version` (`string`, obrigatório): Versão semântica maior.menor do protocolo (`"1.0"`).
- `type` (`string`, obrigatório): Identificador do tipo da mensagem.
- `timestamp` (`string`, obrigatório): Timestamp UTC em formato ISO-8601 (`RFC 3339`).
- `req_id` (`string`, opcional): UUID v4 usado para correlacionar requisições e respostas (obrigatório em `EXECUTE_ACTION`, `ACTION_RESULT`, `PAIR_REQUEST`, `PAIR_CONFIRM` e `LAYOUT_SYNC`).
- `token` (`string`, opcional): Token persistente de autenticação emitido no `PAIR_CONFIRM`. Obrigatório em todas as mensagens após o pareamento (ou enviado via header `Authorization: Bearer <token>` no handshake WebSocket).
- `payload` (`object`, obrigatório): Corpo específico do tipo de mensagem.

---

## 3. Fluxo de Pareamento e Autenticação

### 3.1. `PAIR_REQUEST` (Mobile → Desktop)
Inicia o pareamento usando um **PIN de 6 dígitos** exibido no Desktop Agent ou um **QR Code** escaneado pelo Mobile Client.

- **Schema:** [`schemas/pair_request.schema.json`](./schemas/pair_request.schema.json)
- **Exemplo:** [`examples/pair_request.json`](./examples/pair_request.json)
- **Campos de `payload`:**
  - `method`: `"pin"` ou `"qr"`.
  - `pin`: String de exatamente 6 dígitos numéricos (obrigatório quando `method == "pin"`).
  - `qr_nonce`: Token temporário único lido do QR Code (obrigatório quando `method == "qr"`, validade máxima de 120 segundos).
  - `device_id`: Identificador estável do dispositivo móvel (UUID).
  - `device_name`: Nome legível (ex.: `"Galaxy Tab S9 - Ponte"`).
  - `platform`: `"android"` | `"ios"` | `"ipados"`.
  - `app_version`: Versão do app mobile.

### 3.2. `PAIR_CONFIRM` (Desktop → Mobile)
Resposta do Desktop Agent confirmando ou rejeitando o pareamento. Em caso de sucesso, emite um **token persistente** armazenado com segurança no Keystore/Keychain do mobile e com hash SHA-256 salvo no Desktop Agent.

- **Schema:** [`schemas/pair_confirm.schema.json`](./schemas/pair_confirm.schema.json)
- **Exemplo:** [`examples/pair_confirm.json`](./examples/pair_confirm.json)
- **Campos de `payload`:**
  - `status`: `"approved"` | `"rejected"` | `"expired"`.
  - `auth_token`: Token opaco persistente (presente apenas quando `status == "approved"`).
  - `agent_id`: UUID do Desktop Agent.
  - `agent_name`: Hostname ou nome configurado do PC.
  - `os`: `"windows"` | `"linux"`.
  - `telemetry_interval_ms`: Intervalo padrão de telemetria configurado (500–1000 ms).
  - `error_code` / `error_message`: Detalhes quando `status != "approved"`.

---

## 4. Sincronização de Capacidades

### 4.1. `CAPABILITIES_SYNC` (Desktop → Mobile)
Enviado imediatamente após autenticação bem-sucedida e sempre que o usuário adicionar, editar ou remover ações no Desktop Agent.

- **Schema:** [`schemas/capabilities_sync.schema.json`](./schemas/capabilities_sync.schema.json)
- **Exemplo:** [`examples/capabilities_sync.json`](./examples/capabilities_sync.json)
- **Campos de `payload`:**
  - `revision`: Número inteiro monotônico da revisão da configuração.
  - `actions`: Lista de ações executáveis cadastradas no PC:
    - `id`: Identificador único estável (ex.: `"act_open_vscode"`).
    - `name`: Rótulo curto exibido no botão LCARS.
    - `category`: Categoria lógica (ex.: `"apps"`, `"system"`, `"media"`, `"scripts"`, `"macros"`).
    - `command_type`: `"shell"` | `"app_launch"` | `"hotkey"` | `"http_webhook"` | `"media_key"` | `"system_power"`.
    - `icon`: Nome simbólico opcional.
    - `color_token`: Token de cor da paleta LCARS (ex.: `"amber"`, `"peach"`, `"lavender"`, `"cyan"`, `"red_alert"`).
    - `confirm_required`: Booleano indicando se o mobile deve pedir confirmação antes de disparar (ex.: desligar PC).
  - `sensors`: Lista de sensores de hardware disponíveis na máquina:
    - `id`: Identificador do sensor (ex.: `"cpu_total"`, `"ram"`, `"cpu_temp"`, `"net_eth0"`).
    - `label`: Nome amigável.
    - `kind`: `"cpu"` | `"memory"` | `"temperature"` | `"network"` | `"gpu"` | `"disk"`.
    - `unit`: `"%"` | `"MB"` | `"GB"` | `"C"` | `"KB/s"` | `"MB/s"`.
    - `available`: Booleano.

---

## 5. Telemetria em Tempo Real

### 5.1. `TELEMETRY` (Desktop → Mobile)
Pacote periódico enviado pelo PC a cada **500 ms – 1000 ms** (configurável; padrão `750 ms`). Em conexões BLE, o agente pode aplicar *throttling* automático para `1000 ms` se o buffer estiver saturado.

- **Schema:** [`schemas/telemetry.schema.json`](./schemas/telemetry.schema.json)
- **Exemplo:** [`examples/telemetry.json`](./examples/telemetry.json)
- **Campos de `payload`:**
  - `interval_ms`: Intervalo atual de amostragem (500–1000).
  - `cpu`:
    - `usage_percent`: Uso agregado de CPU (`0.0` a `100.0`).
    - `per_core_percent`: Array opcional com uso por núcleo.
    - `frequency_mhz`: Frequência média opcional.
  - `memory`:
    - `total_bytes`: Memória RAM total em bytes.
    - `free_bytes`: Memória RAM livre/disponível em bytes.
    - `used_bytes`: Memória RAM utilizada em bytes.
    - `usage_percent`: Percentual utilizado (`0.0` a `100.0`).
  - `temperature`: Objeto opcional (`null` se não houver sensor disponível):
    - `cpu_celsius`: Temperatura do pacote/CPU em °C (nullable).
    - `gpu_celsius`: Temperatura da GPU em °C (nullable).
    - `sensors`: Lista opcional de leituras adicionais `{ "label": string, "celsius": number }`.
  - `network`:
    - `interface`: Nome da interface primária ativa (ex.: `"enp4s0"`, `"Wi-Fi"`).
    - `rx_bytes_per_sec`: Taxa de download atual em bytes/s.
    - `tx_bytes_per_sec`: Taxa de upload atual em bytes/s.

---

## 6. Execução de Ações

### 6.1. `EXECUTE_ACTION` (Mobile → Desktop)
Solicita a execução imediata de uma ação previamente anunciada em `CAPABILITIES_SYNC`.

- **Schema:** [`schemas/execute_action.schema.json`](./schemas/execute_action.schema.json)
- **Exemplo:** [`examples/execute_action.json`](./examples/execute_action.json)
- **Campos de `payload`:**
  - `action_id`: ID da ação cadastrada no Desktop Agent.
  - `args`: Objeto opcional chave/valor com parâmetros dinâmicos permitidos pela ação.

> **Segurança:** O Desktop Agent **nunca** executa comandos arbitrários enviados pelo mobile; ele apenas resolve `action_id` contra o registro local previamente autorizado pelo usuário no PC.

### 6.2. `ACTION_RESULT` (Desktop → Mobile)
Retornado pelo Desktop Agent correlacionado pelo mesmo `req_id` do `EXECUTE_ACTION`.

- **Schema:** [`schemas/action_result.schema.json`](./schemas/action_result.schema.json)
- **Exemplo:** [`examples/action_result.json`](./examples/action_result.json)
- **Campos de `payload`:**
  - `action_id`: ID da ação executada.
  - `status`: `"ok"` | `"error"` | `"denied"` | `"not_found"` | `"timeout"`.
  - `exit_code`: Código de saída do processo (quando aplicável, nullable).
  - `duration_ms`: Duração da execução em milissegundos.
  - `message`: Mensagem resumida de retorno ou motivo do erro.

---

## 7. Sincronização e Backup de Layout

### 7.1. `LAYOUT_SYNC` (Bidirecional: Mobile ↔ Desktop)
Transporta a definição completa da grade visual LCARS configurada no aplicativo mobile para backup persistente no Desktop Agent (ou restauração para um novo dispositivo).

- **Schema:** [`schemas/layout_sync.schema.json`](./schemas/layout_sync.schema.json)
- **Exemplo:** [`examples/layout_sync.json`](./examples/layout_sync.json)
- **Campos de `payload`:**
  - `direction`: `"push"` (Mobile → Desktop, salvar backup) | `"pull_request"` (Mobile → Desktop, solicitar último backup) | `"pull_response"` (Desktop → Mobile, restaurar backup).
  - `layout_version`: Inteiro incremental para resolução de conflitos.
  - `updated_at`: Timestamp ISO-8601 da última modificação.
  - `profile_name`: Nome do perfil/painel (ex.: `"Ponte Principal"`).
  - `grid`: `{ "columns": number, "rows": number, "orientation": "landscape" | "portrait" }`.
  - `pages`: Lista de páginas/abas LCARS, cada uma contendo `id`, `title`, `accent_color` e `blocks`:
    - **Blocos de Execução (`block_type: "action"`):** Vinculados a um `action_id` do PC, posição `(col, row, col_span, row_span)`, rótulo, cor LCARS e som tátil opcional.
    - **Blocos de Informação Read-Only (`block_type: "info"`):**
      - `source: "pc_telemetry"` — Exibe métricas vindas do pacote `TELEMETRY` (ex.: `cpu.usage_percent`, `memory.usage_percent`, `temperature.cpu_celsius`, `network.rx_bytes_per_sec`).
      - `source: "local_device"` — Exibe informações locais do tablet/smartphone (ex.: `clock`, `stardate`, `battery_level`, `connection_status`).

---

## 8. Códigos de Erro Padronizados

| Código | Significado |
| :--- | :--- |
| `ERR_INVALID_PIN` | PIN de 6 dígitos incorreto |
| `ERR_QR_EXPIRED` | Nonce do QR Code expirado ou já utilizado |
| `ERR_UNAUTHORIZED` | Token ausente, revogado ou inválido |
| `ERR_ACTION_NOT_FOUND` | `action_id` não existe no catálogo do agente |
| `ERR_ACTION_EXEC_FAILED` | Falha ao executar processo/comando no sistema operacional |
| `ERR_LAYOUT_CONFLICT` | `layout_version` enviado é menor que o armazenado no servidor |
| `ERR_MALFORMED_FRAME` | JSON inválido ou fora do schema do protocolo |
