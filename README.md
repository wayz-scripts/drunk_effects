# Drift Assist (Standalone, optional QBCore) — v1.0.3

Assisted drifting with a single toggle command, runtime handling edits, launch assist, and safe restoration when disabled or the resource stops.

**Tags:** free, standalone, qbcore-optional, drift, handling, client-side  
**Tested on:** FXServer (cerulean)  
**License:** MIT

---

## ✨ Features
- **Command-only:** `/drift` (no keybinds).
- **Runtime handling:** temporary changes only; no `handling.meta` edits.
- **Launch assist:** temporary power/torque bump at low speed.
- **Grip pulses:** short traction reduction windows to keep the slide stable.
- **Speed cap while drifting** with automatic restore when off.
- **Safe vehicle switching:** reapplies preset if drift is ON; restores if you exit the driver seat.
- **Optional QBCore:** uses `QBCore.Functions.Notify` if present, otherwise silent.

---

## 📦 Requirements
- None for core usage.
- **Optional:** QBCore for notifications.

---

## 🔧 Installation
1. Place the resource folder under `resources/[free]/reb_drift`.
2. In your `server.cfg`:
