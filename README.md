## LA-AROX / FINAL ENGLISH Script - Configuration Guide

This document explains **what you need to configure** and **why each setting matters**. The script automates and fix bugs and errors of auto titus on AROX script (DEEPWOKEN) with safety features, auto-joins, teleportation, and Discord webhook alerts.

---

## VELOCITY AND USABILITY
The script can be slow at times; this is because the script's focus is on usability, allowing it to run for hours without worrying about whether it will crash or not.

---

## ⚠️ IMPORTANT: Execution Location

**You MUST execute this script while standing near the Titus dungeon portal.**  
The script verifies your distance to the portal destination (`-6881, 336, 2829`). If you're more than 100 studs away, it will show an error, stop all functions, and spam the exit button. This ensures the teleportation feature works correctly.

---

## Required Configuration

### 1. Script Key (`getgenv().script_key`)
**What to configure:**
```lua
getgenv().script_key = "YOUR_KEY_HERE"
```

**Why:** This is the authentication key required by the AROX script. Without a valid key, the script won't load the AROX script.

---

### 2. Discord Webhook (`DISCORD_WEBHOOK`)
**What to configure:**
```lua
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
```

**Why:** The script sends errors, alerts and inventory reports (relics, food, vital stats) to your Discord webhook as an embed. If this is empty or invalid, you won't receive any notifications. The webhook must be a valid Discord webhook URL.

---

## Optional Configuration (Advanced Users Only)

> ⚠️ **Warning:** Only modify these if you understand their impact. Default values are tested and recommended.

### 3. Minimum Vital Stats (`MIN_STOMACH`, `MIN_WATER`, `MIN_BLOOD`)
**Default:** `30` for each

**What it does:** Sets the minimum percentage threshold for Stomach, Water, and Blood before the script triggers an emergency shutdown.

**Why you might change it:**
- **Lower values (e.g., 20):** More lenient, allows lower vitals before triggering.
- **Higher values (e.g., 50):** More strict, triggers earlier to prevent death.

**Why it matters:** If any vital stat drops below these thresholds, the script will:
1. Stop all automated functions
2. Show an error popup
3. Send a Discord alert
4. Spam the exit button to leave the server

---

### 4. AROX Execution Timeout (`TIMEOUT_AROX_EXECUTION`)
**Default:** `15` seconds

**What it does:** Countdown timer before the script automatically loads the AROX script.

**Why you might change it:**
- **Shorter (e.g., 15):** Faster execution, less time to cancel.
- **Longer (e.g., 35):** More time to cancel with Right Control if needed.

**Why this is important:** Once the character's location is validated, this timer will start. You can cancel it with the right Ctrl key during the countdown. After the timer finishes, the AROX script will be injected automatically.

---

### 5. Leave Timer (`LEAVE_TIMER`)
**Default:** `120` seconds (2 minutes)

**What it does:** Timeout duration for the auto-leave feature (toggled with `Right Alt`).

**Reasons to change:**
- **Shorter (e.g., 60):** Exits faster, good for a high-performance PC.
- **Longer (e.g., 180):** Remains longer, good for a mid-range or lower-end PC.

**Why it matters:** When enabled, the script counts down from this value. When it reaches 0, it continuously clicks the exit button to return to the lobby. This prevents you from staying in a server too long for any reason, like if the arox script crashes.

---

### 6. Teleport Wait Time (`WAIT_TIME_TELEPORT`)
**Default:** `15` seconds

**What it does:** Countdown before teleporting to the Titus portal position.

**Why you might change it:**
- **Shorter (e.g., 5):** Teleports faster after script execution.
- **Longer (e.g., 30):** More time to prepare before teleportation.

**Why it matters:** After the AROX script is executed, the script waits this duration before initiating the teleport. This gives the script time to load properly and ensures the teleportation works correctly.

---

### 7. Auto Press Interval (`AUTO_PRESS_INTERVAL`)
**Default:** `20` seconds

**What it does:** Time interval between automatic presses of the `1` key when not in lobby.

**Why you might change it:**
- **Shorter (e.g., 10):** More frequent key presses.
- **Longer (e.g., 30):** Less frequent key presses.

**Why it matters:** The script automatically presses the `1` key at this interval to prevent the character from getting stuck inside the Titus portal (inside the dungeon) without teleporting correctly.

---

### 8. Detector Distance (`DETECTOR_DISTANCE_LEAVE`)
**Default:** `500` studs

**What it does:** Distance threshold that triggers the player detector to automatically spam the exit button.

**Why you might change it:**
- **Shorter (e.g., 300):** Only triggers when players are very close.
- **Longer (e.g., 700):** Triggers when players are further away.

**Why it matters:** When the detector is enabled (`Insert` key), it monitors nearby players. If any player comes within this distance, the script automatically starts clicking the exit button to leave the server, protecting you from potential threats.

---

## Hotkeys Reference

| Key | Feature | What It Does |
|-----|---------|---------------|
| `Insert` | Player Detector | Toggles automatic detection of nearby players. When enabled and a player is within `DETECTOR_DISTANCE_LEAVE`, it spams the exit button. |
| `PageUp` | Mod Detector | Toggles detection of moderators (group rank > 0 in group 5212858). Auto-leaves if a moderator is detected. |
| `PageDown` | Vitals Monitor | Toggles periodic vital stats checking. When enabled, checks every 30 seconds. |
| `Right Alt` | Auto Leave Timer | Toggles the auto-leave timer. When enabled, counts down from `LEAVE_TIMER` and leaves when it reaches 0. |
| `End` | Auto Press 1 | Toggles automatic `1` key presses every `AUTO_PRESS_INTERVAL` seconds. |
| `Home` | Auto Join | Toggles automatic server joining. Clicks "AUTO TITUS" slot and uses Quick Join. |
| `Right Control` | Cancel Execution | Cancels the AROX script execution countdown (only works during the timeout period). |

---

## Webhook Requirements

- **Executor Support:** Your executor must support `http_request` function.
- **Format:** The webhook sends a Discord embed with:
  - Player name
  - List of relics (with quantities)
  - List of food items (with quantities)
  - Vital stats (Stomach, Water, Blood percentages)
- **Frequency:** The webhook is sent **once per execution** after all data is collected.

---

## Acknowledgments

Special thanks to **AROX SCRIPT** for creating the main script that made this automation possible.
If you have any questions or would like to get in touch, talk to me on Discord (lipegte)
Or via email (felipeestrela2006@gmail.com)

---

**Enjoy, stay safe, and good luck in DeepWoken! 🗡️**

