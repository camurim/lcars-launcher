export type SupportedLang = "en" | "pt" | "es";

const STORAGE_KEY = "lcars_desktop_lang";

export const TRANSLATIONS: Record<SupportedLang, Record<string, string>> = {
  en: {
    subtitle: "WebSocket + mDNS Daemon • Protocol v1.0",
    trayBadge: "Running in tray",
    tabActions: "1. Actions",
    tabPairing: "2. Pairing",
    tabDevices: "3. Devices",
    labelActionName: "Action Name",
    labelCategory: "Category",
    labelTarget: "Executable, Script or URL",
    labelPreset: "Native PC Control",
    labelArgs: "Arguments (space-separated)",
    labelExecType: "Execution Type",
    optAppLaunch: "Launch App / URL (detached)",
    optShell: "Command with Output (show text on panel)",
    optMediaKey: "Audio / Media Control (PC)",
    optSystemPower: "System / Power Control (PC)",
    labelColor: "Panel Color",
    btnCancel: "Cancel",
    btnSaveAction: "Save Action",
    savedActionsTitle: "Registered Actions",
    noActions: "No registered actions.",
    actionsCount: "{n} actions",
    btnEdit: "Edit",
    btnDelete: "Delete",
    pairingTitle: "Connection & Temporary PIN",
    labelLocalIp: "Local IP",
    labelWsPort: "WS Port",
    labelPin6: "6-Digit PIN",
    usbPinNote: "Note: even over USB, enter this 6-digit PIN in the mobile app to pair.",
    btnRegenPin: "Generate New PIN & QR Code",
    btnAdbReverse: "Enable USB Tunnel (ADB Reverse)",
    adbConfiguring: "Configuring ADB tunnel...",
    qrTitle: "Quick Pairing (QR Code)",
    devicesTitle: "Authorized Tablets & Smartphones",
    btnRefresh: "Refresh",
    noDevices: "No paired devices yet. Use the Pairing tab to authorize a tablet or smartphone.",
    btnRevoke: "Revoke Access",
    pairedAt: "Paired on",
    preset_volume_up: "PC Volume +5%",
    preset_volume_down: "PC Volume -5%",
    preset_volume_mute: "PC Mute / Sound",
    preset_mic_mute: "Mute / Unmute Microphone",
    preset_play_pause: "Media Play / Pause",
    preset_next_track: "Next Track",
    preset_prev_track: "Previous Track",
    preset_lock_screen: "Lock Screen",
    preset_suspend: "Suspend / Sleep PC",
    btnExportBackup: "Export Backup",
    btnImportBackup: "Import Backup",
    backupExportedOk: "Backup JSON downloaded successfully.",
    backupImporting: "Reading and validating backup file...",
    backupImportedOk: "Backup restored and synced with connected devices!",
    backupImportedSummary: "Backup restored ({actions} actions, {devices} paired devices{layout}).",
    backupLayoutIncluded: ", layout restored",
    backupImportError: "Failed to restore backup: {err}",
    backupEmptyFile: "The selected file is empty.",
  },
  pt: {
    subtitle: "Daemon WebSocket + mDNS • Protocolo v1.0",
    trayBadge: "Em execução na bandeja",
    tabActions: "1. Ações",
    tabPairing: "2. Pareamento",
    tabDevices: "3. Dispositivos",
    labelActionName: "Nome da Ação",
    labelCategory: "Categoria",
    labelTarget: "Executável, Script ou URL",
    labelPreset: "Controle Nativo do PC",
    labelArgs: "Argumentos (separados por espaço)",
    labelExecType: "Tipo de Execução",
    optAppLaunch: "Abrir App / URL (desacoplado)",
    optShell: "Comando com Saída (exibir texto no painel)",
    optMediaKey: "Controle de Áudio / Mídia (PC)",
    optSystemPower: "Controle de Sistema / Energia (PC)",
    labelColor: "Cor do Painel",
    btnCancel: "Cancelar",
    btnSaveAction: "Salvar Ação",
    savedActionsTitle: "Ações Cadastradas",
    noActions: "Nenhuma ação cadastrada.",
    actionsCount: "{n} ações",
    btnEdit: "Editar",
    btnDelete: "Excluir",
    pairingTitle: "Conexão & PIN Temporário",
    labelLocalIp: "IP Local",
    labelWsPort: "Porta WS",
    labelPin6: "PIN de 6 Dígitos",
    usbPinNote: "Nota: mesmo via cabo USB, informe este PIN de 6 dígitos no app mobile para parear.",
    btnRegenPin: "Gerar Novo PIN e QR Code",
    btnAdbReverse: "Ativar Túnel USB (ADB Reverse)",
    adbConfiguring: "Configurando túnel ADB...",
    qrTitle: "Pareamento Rápido (QR Code)",
    devicesTitle: "Tablets & Smartphones Autorizados",
    btnRefresh: "Atualizar",
    noDevices: "Nenhum dispositivo pareado ainda. Use a aba Pareamento para autorizar um tablet ou smartphone.",
    btnRevoke: "Revogar Acesso",
    pairedAt: "Pareado em",
    preset_volume_up: "Volume do PC +5%",
    preset_volume_down: "Volume do PC -5%",
    preset_volume_mute: "Mudo / Som (PC)",
    preset_mic_mute: "Mutar / Ativar Microfone",
    preset_play_pause: "Play / Pause Mídia",
    preset_next_track: "Próxima Faixa",
    preset_prev_track: "Faixa Anterior",
    preset_lock_screen: "Bloquear Tela",
    preset_suspend: "Suspender / Dormir PC",
    btnExportBackup: "Exportar Backup",
    btnImportBackup: "Importar Backup",
    backupExportedOk: "Arquivo JSON de backup baixado com sucesso.",
    backupImporting: "Lendo e validando arquivo de backup...",
    backupImportedOk: "Backup restaurado e sincronizado com os dispositivos!",
    backupImportedSummary: "Backup restaurado ({actions} ações, {devices} dispositivos pareados{layout}).",
    backupLayoutIncluded: ", layout restaurado",
    backupImportError: "Falha ao restaurar backup: {err}",
    backupEmptyFile: "O arquivo selecionado está vazio.",
  },
  es: {
    subtitle: "Daemon WebSocket + mDNS • Protocolo v1.0",
    trayBadge: "En ejecución en bandeja",
    tabActions: "1. Acciones",
    tabPairing: "2. Emparejamiento",
    tabDevices: "3. Dispositivos",
    labelActionName: "Nombre de la Acción",
    labelCategory: "Categoría",
    labelTarget: "Ejecutable, Script o URL",
    labelPreset: "Control Nativo del PC",
    labelArgs: "Argumentos (separados por espacio)",
    labelExecType: "Tipo de Ejecución",
    optAppLaunch: "Abrir App / URL (desacoplado)",
    optShell: "Comando con Salida (mostrar texto en panel)",
    optMediaKey: "Control de Audio / Medios (PC)",
    optSystemPower: "Control de Sistema / Energía (PC)",
    labelColor: "Color del Panel",
    btnCancel: "Cancelar",
    btnSaveAction: "Guardar Acción",
    savedActionsTitle: "Acciones Registradas",
    noActions: "Ninguna acción registrada.",
    actionsCount: "{n} acciones",
    btnEdit: "Editar",
    btnDelete: "Eliminar",
    pairingTitle: "Conexión y PIN Temporal",
    labelLocalIp: "IP Local",
    labelWsPort: "Puerto WS",
    labelPin6: "PIN de 6 Dígitos",
    usbPinNote: "Nota: incluso por cable USB, ingrese este PIN de 6 dígitos en la app móvil para emparejar.",
    btnRegenPin: "Generar Nuevo PIN y Código QR",
    btnAdbReverse: "Activar Túnel USB (ADB Reverse)",
    adbConfiguring: "Configurando túnel ADB...",
    qrTitle: "Emparejamiento Rápido (Código QR)",
    devicesTitle: "Tablets y Smartphones Autorizados",
    btnRefresh: "Actualizar",
    noDevices: "Aún no hay dispositivos emparejados. Use la pestaña Emparejamiento para autorizar una tablet o smartphone.",
    btnRevoke: "Revocar Acceso",
    pairedAt: "Emparejado el",
    preset_volume_up: "Volumen del PC +5%",
    preset_volume_down: "Volumen del PC -5%",
    preset_volume_mute: "Silencio / Sonido (PC)",
    preset_mic_mute: "Silenciar / Activar Micrófono",
    preset_play_pause: "Reproducir / Pausar Medios",
    preset_next_track: "Pista Siguiente",
    preset_prev_track: "Pista Anterior",
    preset_lock_screen: "Bloquear Pantalla",
    preset_suspend: "Suspender / Dormir PC",
    btnExportBackup: "Exportar Respaldo",
    btnImportBackup: "Importar Respaldo",
    backupExportedOk: "Archivo JSON de respaldo descargado con éxito.",
    backupImporting: "Leyendo y validando archivo de respaldo...",
    backupImportedOk: "¡Respaldo restaurado y sincronizado con los dispositivos!",
    backupImportedSummary: "Respaldo restaurado ({actions} acciones, {devices} dispositivos emparejados{layout}).",
    backupLayoutIncluded: ", diseño restaurado",
    backupImportError: "Error al restaurar respaldo: {err}",
    backupEmptyFile: "El archivo seleccionado está vacío.",
  },
};

export function detectInitialLang(): SupportedLang {
  const saved = localStorage.getItem(STORAGE_KEY) as SupportedLang | null;
  if (saved && saved in TRANSLATIONS) return saved;
  const nav = (navigator.language || "en").toLowerCase();
  if (nav.startsWith("pt")) return "pt";
  if (nav.startsWith("es")) return "es";
  return "en";
}

let currentLang: SupportedLang = detectInitialLang();

export function getLang(): SupportedLang {
  return currentLang;
}

export function setLang(lang: SupportedLang) {
  currentLang = lang;
  localStorage.setItem(STORAGE_KEY, lang);
  document.documentElement.lang = lang;
  applyDomTranslations();
}

export function t(key: string, params?: Record<string, string | number>): string {
  let text = TRANSLATIONS[currentLang][key] ?? TRANSLATIONS.en[key] ?? key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      text = text.replace(`{${k}}`, String(v));
    }
  }
  return text;
}

export function applyDomTranslations() {
  document.querySelectorAll<HTMLElement>("[data-i18n]").forEach((el) => {
    const key = el.dataset.i18n;
    if (key) el.textContent = t(key);
  });
}
