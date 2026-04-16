# My Custom ML4W-Calendar with Google Calendar Support
I want to share my custom quickshell calendar based on ML4W quickshell calendar itself with Google Calendar support. Customize by Google Gemini AI, so don't ask me anything because I do not understand advanced coding. Thanks.

---

# 📅 ML4W Quickshell Google Calendar Widget

A highly functional, interactive Google Calendar widget built for Quickshell! This widget allows you to view your events, quickly add new ones, and delete them right from your desktop.

## ✨ Features
* **Syncs with Google Calendar:** Real-time sync using `gcalcli`.
* **Interactive UI:** Click on any event to view details, delete it, or open it in your browser.
* **Quick Add:** Type natural language like "Dinner tomorrow at 19:00" to instantly add events.
* **Smart Colors:** Distinct colors for national holidays and personal events.
* **Slide Animation:** Smooth slide-in/slide-out animation from the right edge of your screen.

---

## 🛠️ Prerequisites

Before using this widget, you need to install and configure **gcalcli** (Google Calendar Command Line Interface).

### 1. Install `gcalcli`
Open your terminal and install the package:
```bash
# For Arch Linux / EndeavourOS / Garuda
sudo pacman -S gcalcli
```

### 2. Configure Google API (Crucial Step!)
By default, `gcalcli` might face rate limits. You need to create your own Google API Client ID for it to work flawlessly.

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new Project (e.g., "My Gcalcli").
3. Enable the **Google Calendar API** for this project.
4. Go to **Credentials** -> **Create Credentials** -> **OAuth client ID**.
5. Choose **Desktop App**.
6. You will get a **Client ID** and a **Client Secret**.

### 3. Authenticate `gcalcli`
Run this command in your terminal, replacing the placeholders with your actual keys:

```bash
gcalcli --client-id="YOUR_CLIENT_ID" --client-secret="YOUR_CLIENT_SECRET" list
```
* Your browser will open. Log in to your Google Account and grant permission.
* Once done, `gcalcli` is fully set up!

---

## 🚀 Installation & Setup

1. **Save the File:**
   Download the provided `CalendarWindow.qml` and save it to your Quickshell configuration directory exactly here:
   `~/.config/quickshell/CalendarApp/CalendarWindow.qml`

2. **Set Your Email:**
   Open `CalendarWindow.qml` with your text editor. At the very top (around line 23), find this line:
   ```qml
   property string primaryCalendar: "your_email@gmail.com"
   ```
   **Change "your_email@gmail.com" to the actual Google Account email you used to set up `gcalcli`.**

3. **Call the Widget:**
   Make sure you have a button or a shortcut in your Hyprland/Waybar config that sends an IPC signal to Quickshell to toggle this window

## 🎮 How to Use
* **Quick Add:** Click "+ Add Event", type your plan (e.g., "Meeting with Boss Friday at 14:00"), and hit Save.
* **Delete Event:** Click on any personal event on the list, then press the red "Delete" button.
* **Edit in Web:** Click on an event, press "Edit in Web", and your browser will instantly open Google Calendar directly to that specific day!
