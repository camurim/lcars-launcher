import "./styles.css";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import QRCode from "qrcode";
import {
  applyDomTranslations,
  getLang,
  setLang,
  type SupportedLang,
  t,
} from "./i18n";

interface RegisteredAction {
  id: string;
  name: string;
  category: string;
  command_type: string;
  target: string;
  args: string[];
  color_token?: string;
  confirm_required: boolean;
}

interface PairingInfo {
  agent_name: string;
  os: string;
  ip: string;
  port: number;
  pin: string;
  ws_url: string;
  qr_payload: string;
  mdns_service: string;
  telemetry_interval_ms: number;
}

interface PairedDevice {
  device_id: string;
  device_name: string;
  platform: string;
  token: string;
  paired_at: string;
}

type TabKey = "actions" | "pairing" | "devices";

let currentActions: RegisteredAction[] = [];

// Elementos DOM
const tabButtons = document.querySelectorAll<HTMLButtonElement>(".tab-btn");
const panels: Record<TabKey, HTMLElement> = {
  actions: document.getElementById("panel-actions") as HTMLElement,
  pairing: document.getElementById("panel-pairing") as HTMLElement,
  devices: document.getElementById("panel-devices") as HTMLElement,
};

const actionForm = document.getElementById("action-form") as HTMLFormElement;
const actIdInput = document.getElementById("act-id") as HTMLInputElement;
const actNameInput = document.getElementById("act-name") as HTMLInputElement;
const actCategoryInput = document.getElementById("act-category") as HTMLInputElement;
const actTargetInput = document.getElementById("act-target") as HTMLInputElement;
const actArgsInput = document.getElementById("act-args") as HTMLInputElement;
const actCommandTypeSelect = document.getElementById("act-command-type") as HTMLSelectElement;
const actPresetSelect = document.getElementById("act-preset") as HTMLSelectElement;
const fieldTargetEl = document.getElementById("field-target") as HTMLElement;
const fieldArgsEl = document.getElementById("field-args") as HTMLElement;
const fieldPresetEl = document.getElementById("field-preset") as HTMLElement;
const actColorSelect = document.getElementById("act-color") as HTMLSelectElement;
const langSelect = document.getElementById("lang-select") as HTMLSelectElement;

const MEDIA_PRESET_KEYS = [
  "volume_up",
  "volume_down",
  "volume_mute",
  "mic_mute",
  "play_pause",
  "next_track",
  "prev_track",
];

const SYSTEM_PRESET_KEYS = ["lock_screen", "suspend"];

function syncCommandTypeFields(selectedPreset?: string) {
  const kind = actCommandTypeSelect.value;
  const isPreset = kind === "media_key" || kind === "system_power";
  fieldTargetEl.classList.toggle("hidden", isPreset);
  fieldArgsEl.classList.toggle("hidden", isPreset);
  fieldPresetEl.classList.toggle("hidden", !isPreset);
  actTargetInput.required = !isPreset;

  if (isPreset) {
    const keys = kind === "media_key" ? MEDIA_PRESET_KEYS : SYSTEM_PRESET_KEYS;
    actPresetSelect.innerHTML = "";
    for (const key of keys) {
      const opt = document.createElement("option");
      opt.value = key;
      opt.textContent = t(`preset_${key}`);
      actPresetSelect.appendChild(opt);
    }
    if (selectedPreset && keys.includes(selectedPreset)) {
      actPresetSelect.value = selectedPreset;
    }
    if (!actNameInput.value.trim()) {
      actNameInput.value = t(`preset_${actPresetSelect.value}`).toUpperCase();
    }
  }
}
const cancelEditBtn = document.getElementById("btn-cancel-edit") as HTMLButtonElement;
const actionsListEl = document.getElementById("actions-list") as HTMLUListElement;
const actionsCountEl = document.getElementById("actions-count") as HTMLElement;

const pairIpEl = document.getElementById("pair-ip") as HTMLElement;
const pairPortEl = document.getElementById("pair-port") as HTMLElement;
const pairPinEl = document.getElementById("pair-pin") as HTMLElement;
const pairMdnsEl = document.getElementById("pair-mdns") as HTMLElement;
const pairQrJsonEl = document.getElementById("pair-qr-json") as HTMLElement;
const pairQrCanvas = document.getElementById("pair-qr-canvas") as HTMLCanvasElement;
const regenPinBtn = document.getElementById("btn-regen-pin") as HTMLButtonElement;
const adbReverseBtn = document.getElementById("btn-adb-reverse") as HTMLButtonElement;
const adbStatusEl = document.getElementById("adb-status") as HTMLElement;

const devicesListEl = document.getElementById("devices-list") as HTMLUListElement;
const refreshDevicesBtn = document.getElementById("btn-refresh-devices") as HTMLButtonElement;

function switchTab(tab: TabKey) {
  for (const btn of tabButtons) {
    const isActive = btn.dataset.tab === tab;
    btn.className = isActive
      ? "tab-btn cursor-pointer rounded-full bg-amber-400 px-4 py-1.5 text-xs font-bold tracking-wider text-black uppercase transition"
      : "tab-btn cursor-pointer rounded-full bg-zinc-900 px-4 py-1.5 text-xs font-bold tracking-wider text-zinc-400 uppercase transition hover:bg-zinc-800 hover:text-zinc-200";
  }

  for (const [key, panel] of Object.entries(panels) as [TabKey, HTMLElement][]) {
    if (key === tab) {
      panel.classList.remove("hidden");
      if (key === "pairing") panel.classList.add("grid");
    } else {
      panel.classList.add("hidden");
      if (key === "pairing") panel.classList.remove("grid");
    }
  }

  if (tab === "pairing") void loadPairingInfo();
  if (tab === "devices") void loadDevices();
}

function resetActionForm() {
  actIdInput.value = "";
  actNameInput.value = "";
  actCategoryInput.value = "apps";
  actTargetInput.value = "";
  actArgsInput.value = "";
  actCommandTypeSelect.value = "app_launch";
  actColorSelect.value = "amber";
  syncCommandTypeFields();
  cancelEditBtn.classList.add("hidden");
}

function renderActions(actions: RegisteredAction[]) {
  currentActions = actions;
  actionsCountEl.textContent = t("actionsCount", { n: actions.length });
  actionsListEl.innerHTML = "";

  if (actions.length === 0) {
    actionsListEl.innerHTML = `<li class="py-4 text-center text-xs text-zinc-500">${t("noActions")}</li>`;
    return;
  }

  for (const act of actions) {
    const li = document.createElement("li");
    li.className =
      "flex flex-wrap items-center justify-between gap-2 rounded-xl border border-zinc-800 bg-zinc-950 px-3 py-2.5";
    li.innerHTML = `
      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold tracking-wider text-amber-200 uppercase">${act.name}</span>
          <span class="rounded-full bg-zinc-800 px-2 py-0.5 text-[10px] text-zinc-300">${act.category}</span>
        </div>
        <div class="mt-0.5 truncate font-mono text-[11px] text-zinc-400">
          ${act.target} ${act.args.join(" ")}
        </div>
      </div>
      <div class="flex items-center gap-2">
        <button data-edit="${act.id}" class="cursor-pointer rounded-lg border border-zinc-700 px-2.5 py-1 text-[11px] text-zinc-200 hover:bg-zinc-800">
          ${t("btnEdit")}
        </button>
        <button data-delete="${act.id}" class="cursor-pointer rounded-lg border border-red-500/40 px-2.5 py-1 text-[11px] text-red-300 hover:bg-red-500/20">
          ${t("btnDelete")}
        </button>
      </div>
    `;
    actionsListEl.appendChild(li);
  }

  actionsListEl.querySelectorAll<HTMLButtonElement>("[data-edit]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const found = currentActions.find((a) => a.id === btn.dataset.edit);
      if (!found) return;
      actIdInput.value = found.id;
      actNameInput.value = found.name;
      actCategoryInput.value = found.category;
      actTargetInput.value = found.target;
      actArgsInput.value = found.args.join(" ");
      actCommandTypeSelect.value = found.command_type || "app_launch";
      syncCommandTypeFields(found.target);
      actColorSelect.value = found.color_token ?? "amber";
      cancelEditBtn.classList.remove("hidden");
    });
  });

  actionsListEl.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const id = btn.dataset.delete;
      if (!id) return;
      try {
        const updated = await invoke<RegisteredAction[]>("delete_action", { actionId: id });
        renderActions(updated);
      } catch (err) {
        console.error("Erro ao excluir ação:", err);
      }
    });
  });
}

async function loadActions() {
  try {
    const actions = await invoke<RegisteredAction[]>("list_actions");
    renderActions(actions);
  } catch {
    renderActions([]);
  }
}

async function renderPairing(info: PairingInfo) {
  pairIpEl.textContent = info.ip;
  pairPortEl.textContent = String(info.port);
  pairPinEl.textContent = info.pin;
  pairMdnsEl.textContent = info.mdns_service;
  pairQrJsonEl.textContent = info.qr_payload;
  await QRCode.toCanvas(pairQrCanvas, info.qr_payload, {
    width: 220,
    margin: 1,
    color: { dark: "#09090b", light: "#ffffff" },
  });
}

async function loadPairingInfo() {
  try {
    const info = await invoke<PairingInfo>("get_pairing_info");
    await renderPairing(info);
  } catch {
    const fallback: PairingInfo = {
      agent_name: "PREVIEW-LOCAL",
      os: "linux",
      ip: "127.0.0.1",
      port: 8765,
      pin: "472905",
      ws_url: "ws://127.0.0.1:8765/ws",
      qr_payload: JSON.stringify({ ip: "127.0.0.1", port: 8765, pin: "472905" }),
      mdns_service: "_lcars-agent._tcp.local.",
      telemetry_interval_ms: 750,
    };
    await renderPairing(fallback);
  }
}

function renderDevices(devices: PairedDevice[]) {
  devicesListEl.innerHTML = "";
  if (devices.length === 0) {
    devicesListEl.innerHTML = `<li class="py-6 text-center text-xs text-zinc-500">${t("noDevices")}</li>`;
    return;
  }

  for (const dev of devices) {
    const li = document.createElement("li");
    li.className =
      "flex items-center justify-between gap-3 rounded-xl border border-zinc-800 bg-zinc-950 px-4 py-3";
    li.innerHTML = `
      <div>
        <div class="text-sm font-bold text-cyan-200">${dev.device_name}</div>
        <div class="text-[11px] text-zinc-400 uppercase">
          ${dev.platform} • ${t("pairedAt")} ${new Date(dev.paired_at).toLocaleString(getLang())}
        </div>
      </div>
      <button data-revoke="${dev.device_id}" class="cursor-pointer rounded-full border border-red-500/50 bg-red-500/10 px-3 py-1 text-xs font-semibold text-red-300 hover:bg-red-500/25">
        ${t("btnRevoke")}
      </button>
    `;
    devicesListEl.appendChild(li);
  }

  devicesListEl.querySelectorAll<HTMLButtonElement>("[data-revoke]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const deviceId = btn.dataset.revoke;
      if (!deviceId) return;
      try {
        const updated = await invoke<PairedDevice[]>("revoke_device", { deviceId });
        renderDevices(updated);
      } catch (err) {
        console.error("Erro ao revogar dispositivo:", err);
      }
    });
  });
}

async function loadDevices() {
  try {
    const devices = await invoke<PairedDevice[]>("list_devices");
    renderDevices(devices);
  } catch {
    renderDevices([]);
  }
}

// Eventos
tabButtons.forEach((btn) => {
  btn.addEventListener("click", () => switchTab(btn.dataset.tab as TabKey));
});

cancelEditBtn.addEventListener("click", resetActionForm);
actCommandTypeSelect.addEventListener("change", () => syncCommandTypeFields());
actPresetSelect.addEventListener("change", () => {
  actNameInput.value = t(`preset_${actPresetSelect.value}`).toUpperCase();
});
langSelect.value = getLang();
langSelect.addEventListener("change", () => {
  setLang(langSelect.value as SupportedLang);
  syncCommandTypeFields(actPresetSelect.value);
  renderActions(currentActions);
  void loadDevices();
});

actionForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const cmdType = actCommandTypeSelect.value;
  const isPreset = cmdType === "media_key" || cmdType === "system_power";
  const target = isPreset ? actPresetSelect.value : actTargetInput.value;
  const args = isPreset
    ? []
    : actArgsInput.value
        .trim()
        .split(/\s+/)
        .filter((s) => s.length > 0);
  try {
    const updated = await invoke<RegisteredAction[]>("save_action", {
      input: {
        id: actIdInput.value || null,
        name: actNameInput.value,
        category: actCategoryInput.value,
        target,
        args,
        color_token: actColorSelect.value,
        command_type: cmdType,
        confirm_required: cmdType === "system_power",
      },
    });
    renderActions(updated);
    resetActionForm();
  } catch (err) {
    console.error("Erro ao salvar ação:", err);
  }
});

regenPinBtn.addEventListener("click", async () => {
  try {
    const info = await invoke<PairingInfo>("regenerate_pin");
    await renderPairing(info);
  } catch {
    await loadPairingInfo();
  }
});

adbReverseBtn.addEventListener("click", async () => {
  adbStatusEl.classList.remove("hidden", "text-emerald-300", "text-red-300");
  adbStatusEl.textContent = t("adbConfiguring");
  try {
    const msg = await invoke<string>("setup_adb_reverse");
    adbStatusEl.classList.add("text-emerald-300");
    adbStatusEl.textContent = msg;
  } catch (err) {
    adbStatusEl.classList.add("text-red-300");
    adbStatusEl.textContent = String(err);
  }
});

refreshDevicesBtn.addEventListener("click", () => void loadDevices());

// Escuta navegação enviada pelo menu do System Tray
listen<string>("navigate-tab", (event) => {
  const target = event.payload as TabKey;
  if (target === "actions" || target === "pairing" || target === "devices") {
    switchTab(target);
  }
}).catch(() => {
  // Ignora fora do runtime Tauri
});

applyDomTranslations();
switchTab("actions");
void loadActions();
