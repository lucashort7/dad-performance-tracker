# Dead as Disco - Performance Tracker

A professional-grade performance tracking mod for **Dead as Disco**, developed with a focus on modularity, real-time feedback, and high-fidelity integration.

## 🚀 Features

- **Real-Time Accuracy Tracking:** Monitor your precision stats for every combat action (Attack, Dodge, Parry, etc.) as you play.
- **Dynamic Rank System:** Receive a qualitative grade (S, A, B, C, D) based on your performance at the end of every song.
- **Modular HUD System:**
    - **In-Game Progress HUD:** Live breakdown of hits and accuracy.
    - **Status Indicator:** Persistent confirmation of mod state (ON/OFF).
    - **Results Screen:** Stylized performance report matching the game's aesthetic.
- **Achievement Tracking:** Support for **Max Combo**, **Full Combo (FC)**, and **Perfect FC** detection.
- **Song Identification:** Automatically detects the current track name and displays it in reports.
- **Persistent Preferences:** The mod remembers your HUD visibility settings (F3 toggle) even across respawns and song restarts.
- **High-Performance Architecture:** Optimized Lua hooks and a centralized UMG factory for minimal impact on game frame rates.

## ⌨️ Controls

- **F3:** Toggle In-Game Progress HUD visibility.
- **F4:** Force Show HUD.
- **F5:** Force Hide HUD.

## 🛠️ Installation

1. Ensure you have **UE4SS** installed.
2. Download the `dad-performance-tracker` folder.
3. Extract and place it into your game's `Mods/` directory:  
   `Dead as Disco/Pagoda/Binaries/Win64/ue4ss/Mods/`
4. Enable the mod in your `mods.txt` (or `mods.lua` / UI) by adding `dad-performance-tracker : 1`.

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

## 👤 Credits

Developed by **hort** ([lucashort7](https://github.com/lucashort7))
