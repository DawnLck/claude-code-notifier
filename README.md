<p align="center">
  <img src="claude-code-notifier.svg" width="128" alt="claude-code-notifier logo">
</p>

# claude-code-notifier


[English](#claude-code-notifier) | [简体中文](#claude-code-notifier-zh)

A cross-platform notification hook for [Claude Code](https://claude.ai/code) that fires whenever Claude finishes a task.

**Features:**
- 🖥️ **Cross-platform** — macOS, Linux (X11/Wayland), Windows (WSL2/Git Bash)
- Shows the **first sentence of Claude's last reply** as the notification body — an actual summary of what was done
- Shows **session duration** and **project name** in the subtitle
- On macOS: clicking the notification activates the exact terminal or editor window
- Supports **English** and **Chinese** (auto-detected or manually configured)
- Optional **focus-aware** mode — suppress notification if you're already looking at the terminal
- Works with Terminal, iTerm2, Warp, VS Code, Cursor, Hyper, Alacritty, kitty, Ghostty, GNOME Terminal, Konsole, WezTerm, and more

---

## Demo

```
╔══════════════════════════════════════════════════════╗
║  ✅ Claude Code — Done                               ║
║  Fixed the billing discrepancy in proxy-llm.ts and  ║
║  updated both COST constants.                        ║
║  prompt-miner · 3m 42s · ↩ Warp                     ║
╚══════════════════════════════════════════════════════╝
```
*(Clicking the bubble brings your Warp window to the foreground.)*

---

## Requirements

| Platform | Requirements | Notes |
|---|---|---|
| **All** | [Claude Code](https://claude.ai/code), `jq` | The CLI tool by Anthropic |
| **macOS** | `terminal-notifier` | Click-to-focus support (`brew install terminal-notifier`) |
| **Linux** | `notify-send` (libnotify) | Desktop notifications |
| **Windows (WSL2)** | `powershell.exe` | Built-in, used for Windows Toast notifications |
| **Windows (Git Bash)** | `powershell.exe` | Toast notifications via PowerShell |

> The installer automatically detects your platform and installs the correct dependencies.

---

## Installation

### One-command install (recommended)

```bash
git clone https://github.com/DawnLck/claude-code-notifier.git
cd claude-code-notifier
bash install.sh
```

Then **restart Claude Code** or open `/hooks` to activate.

### Manual install

1. Install dependencies:
   ```bash
   brew install jq terminal-notifier
   ```

2. Copy the hook script:
   ```bash
   mkdir -p ~/.claude/hooks
   cp claude-code-notify.sh ~/.claude/hooks/claude-code-notify.sh
   chmod +x ~/.claude/hooks/claude-code-notify.sh
   ```

3. Register the hook in `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/hooks/claude-code-notify.sh",
               "async": true
             }
           ]
         }
       ]
     }
   }
   ```

4. Restart Claude Code.

---

## Uninstall

```bash
bash install.sh --uninstall
```

---

## How It Works

```
Claude finishes a task
        ↓
Stop hook fires → claude-code-notify.sh receives JSON on stdin
        ↓
1. Extract session_id from stdin JSON
2. Find transcript: ~/.claude/projects/**/<session_id>.jsonl
3. Parse transcript:
   • Duration    → diff between first and last timestamp
   • Project     → decoded from the transcript directory name
   • Summary     → first sentence of Claude's last assistant message
        ↓
4. Detect terminal app:
   TERM_PROGRAM env var → process tree walk → osascript fallback
        ↓
5. Focus check (if NOTIFY_DONE_ONLY_WHEN_AWAY=true):
   Skip notification if the terminal is already frontmost
        ↓
6. Detect language from NOTIFY_DONE_LANG / $LANG / $LC_ALL
        ↓
7. Fire notification via terminal-notifier
   -activate <bundle-id>  ← makes it clickable to open the right window
```

---

## Configuration

All options are set as environment variables in `~/.claude/settings.json`:

```json
{
  "env": {
    "NOTIFY_DONE_LANG":           "zh",
    "NOTIFY_DONE_SHOW_SUMMARY":   "true",
    "NOTIFY_DONE_SHOW_DURATION":  "true",
    "NOTIFY_DONE_SHOW_PROJECT":   "true",
    "NOTIFY_DONE_ONLY_WHEN_AWAY": "false"
  }
}
```

| Variable | Default | Description |
|---|---|---|
| `NOTIFY_DONE_LANG` | auto | Force language: `zh` or `en`. Auto-detects from `$LANG` if unset. |
| `NOTIFY_DONE_SHOW_SUMMARY` | `"true"` | Show Claude's reply summary as the notification body. |
| `NOTIFY_DONE_SHOW_DURATION` | `"true"` | Show task duration in the subtitle. |
| `NOTIFY_DONE_SHOW_PROJECT` | `"true"` | Show project name in the subtitle. |
| `NOTIFY_DONE_ONLY_WHEN_AWAY` | `"false"` | Suppress the notification when the originating terminal is already the frontmost app. |
| `NOTIFY_DONE_SOUND_FILE` | | Absolute path to a .mp3/.wav for custom notification sound. See [Sound Library](sounds/README.md). |

---

## Troubleshooting

**macOS:**
- **Notification doesn't appear**: Check System Settings → Notifications → terminal-notifier.
- **Click doesn't focus**: Verify `terminal-notifier` is installed.

**Linux:**
- **Notification doesn't appear**: Ensure `notify-send` is installed (`apt install libnotify-bin` / `dnf install libnotify`).
- **Focus detection not working**: Requires `xdotool` (X11) or `swaymsg` (Sway/Wayland).

**Windows (WSL2):**
- **No notification**: Ensure `powershell.exe` is accessible from WSL. Try `powershell.exe -Command echo ok`.
- **WSLg users**: Installing `libnotify-bin` inside WSL provides native Linux notification support.

**All platforms:**
- **Summary is generic**: The hook falls back to a locale-appropriate generic string if the transcript isn't ready.

---

<p align="center">
  <img src="claude-code-notifier.svg" width="128" alt="claude-code-notifier logo">
</p>

# <a name="claude-code-notifier-zh"></a>claude-code-notifier (简体中文)


[English](#claude-code-notifier) | [简体中文](#claude-code-notifier-zh)

一个为 [Claude Code](https://claude.ai/code) 提供的跨平台通知钩子，在 Claude 完成任务时触发。

**功能特性：**
- 🖥️ **跨平台支持** — macOS、Linux (X11/Wayland)、Windows (WSL2/Git Bash)
- **显示 Claude 最后回复的第一句话** 作为通知主体 — 真正摘要了所做的工作。
- **显示会话时长和项目名称** 在副标题中。
- **macOS 下点击通知激活对应的终端或编辑器窗口**，直接回到 Claude 运行的地方。
- **支持中英文双语** (自动检测或手动配置)。
- **可选：焦点感知模式** — 如果你正在查看终端，则静默通知。
- **支持多种终端与编辑器**：Terminal, iTerm2, Warp, VS Code, Cursor, Hyper, Alacritty, kitty, Ghostty, GNOME Terminal, Konsole, WezTerm 等。

---

## 演示

```
╔══════════════════════════════════════════════════════╗
║  ✅ Claude Code — 已完成                             ║
║  修复了 proxy-llm.ts 中的计费差异，并更新了两处 COST 常量。║
║  prompt-miner · 3m 42s · ↩ Warp                     ║
╚══════════════════════════════════════════════════════╝
```
*(点击气泡可将 Warp 窗口切换至前台)*

---

## 环境要求

| 平台 | 依赖 | 说明 |
|---|---|---|
| **所有平台** | [Claude Code](https://claude.ai/code)、`jq` | Anthropic 推出的 CLI 工具 |
| **macOS** | `terminal-notifier` | 点击跳转支持 (`brew install terminal-notifier`) |
| **Linux** | `notify-send` (libnotify) | 桌面通知 |
| **Windows (WSL2)** | `powershell.exe` | 内置，用于发送 Windows Toast 通知 |
| **Windows (Git Bash)** | `powershell.exe` | 通过 PowerShell 发送 Toast 通知 |

> 安装脚本会自动检测你的平台并安装对应的依赖。

---

## 安装指南

### 一键安装 (推荐)

```bash
git clone https://github.com/DawnLck/claude-code-notifier.git
cd claude-code-notifier
bash install.sh
```

完成后 **重启 Claude Code** 或输入 `/hooks` 进行激活。

### 手动安装

1. 安装依赖：
   ```bash
   brew install jq terminal-notifier
   ```

2. 复制钩子脚本：
   ```bash
   mkdir -p ~/.claude/hooks
   cp notify-done.sh ~/.claude/hooks/notify-done.sh
   chmod +x ~/.claude/hooks/notify-done.sh
   ```

3. 在 `~/.claude/settings.json` 中配置钩子：
   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/hooks/notify-done.sh",
               "async": true
             }
           ]
         }
       ]
     }
   }
   ```

4. 重启 Claude Code。

---

## 卸载

```bash
bash install.sh --uninstall
```

---

## 工作细节

```
Claude 完成任务
        ↓
触发 Stop 钩子 → notify-done.sh 从 stdin 接收 JSON
        ↓
1. 从 JSON 中提取 session_id
2. 查找会话日志: ~/.claude/projects/**/<session_id>.jsonl
3. 解析日志：
   • 耗时      → 首尾时间戳之差
   • 项目      → 从日志目录名中解码
   • 摘要      • Claude 最后一条回复的第一句话
        ↓
4. 检测终端应用：
   TERM_PROGRAM 环境变量 → 遍历进程树 → osascript 兜底
        ↓
5. 焦点检查 (若 NOTIFY_DONE_ONLY_WHEN_AWAY=true):
   如果终端已在前台，则跳过通知
        ↓
6. 语言检测：
   从 NOTIFY_DONE_LANG / $LANG / $LC_ALL 中识别
        ↓
7. 通过 terminal-notifier 发送通知：
   -activate <bundle-id>  ← 使其可点击并跳转至正确窗口
```

---

## 配置选项

所有选项均作为环境变量在 `~/.claude/settings.json` 中设置：

```json
{
  "env": {
    "NOTIFY_DONE_LANG":           "zh",
    "NOTIFY_DONE_SHOW_SUMMARY":   "true",
    "NOTIFY_DONE_SHOW_DURATION":  "true",
    "NOTIFY_DONE_SHOW_PROJECT":   "true",
    "NOTIFY_DONE_ONLY_WHEN_AWAY": "false"
  }
}
```

| 变量 | 默认值 | 描述 |
|---|---|---|
| `NOTIFY_DONE_LANG` | auto | 强制指定语言：`zh` 或 `en`。未设置时自动检测 `$LANG`。 |
| `NOTIFY_DONE_SHOW_SUMMARY` | `"true"` | 是否在通知正文中显示 Claude 的回复摘要。 |
| `NOTIFY_DONE_SHOW_DURATION` | `"true"` | 是否在副标题中显示任务耗时。 |
| `NOTIFY_DONE_SHOW_PROJECT` | `"true"` | 是否在副标题中显示项目名称。 |
| `NOTIFY_DONE_ONLY_WHEN_AWAY` | `"false"` | 设置为 `"true"` 时，如果所在的终端窗口已处于最前，则不发送通知。 |
| `NOTIFY_DONE_SOUND_FILE` | | 自定义通知音效文件（.mp3/.wav 的绝对路径）。详见 [音效库](sounds/README.md)。 |

---

## 故障排除

**macOS：**
- **通知未出现**：检查 系统设置 → 通知 → 允许 terminal-notifier。
- **点击无法跳转**：确认已安装 `terminal-notifier`。

**Linux：**
- **通知未出现**：确认已安装 `notify-send` (`apt install libnotify-bin` / `dnf install libnotify`)。
- **焦点检测无效**：需要安装 `xdotool` (X11) 或 `swaymsg` (Sway/Wayland)。

**Windows (WSL2)：**
- **无通知**：确认 WSL 内可以访问 `powershell.exe`，尝试 `powershell.exe -Command echo ok`。
- **WSLg 用户**：在 WSL 中安装 `libnotify-bin` 可获得原生 Linux 通知支持。

**所有平台：**
- **摘要内容为空**：如果钩子触发时日志尚未写入，会自动回退到本地化的通用文案。

---

## 参与贡献

欢迎提交 PR！改进方向：
- 更多终端应用的检测支持
- 更多 Linux 桌面环境的适配优化

---

## 开源协议

MIT
