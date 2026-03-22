# claude-code-done-notifier

[English](#claude-code-done-notifier) | [简体中文](#claude-code-done-notifier-zh)

A macOS notification hook for [Claude Code](https://claude.ai/code) that fires whenever Claude finishes a task.

**Features:**
- Shows the **first sentence of Claude's last reply** as the notification body — an actual summary of what was done
- Shows **session duration** and **project name** in the subtitle
- Clicking the notification activates the exact terminal or editor window where Claude is running
- Supports **English** and **Chinese** (auto-detected or manually configured)
- Plays the macOS **Glass** sound on completion
- Optional **focus-aware** mode — suppress notification if you're already looking at the terminal
- Works with Terminal, iTerm2, Warp, VS Code, Cursor, Hyper, Alacritty, kitty, Ghostty

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

| Requirement | Notes |
|---|---|
| macOS | Notifications use native macOS APIs |
| [Claude Code](https://claude.ai/code) | The CLI tool by Anthropic |
| [Homebrew](https://brew.sh) | Used by the installer to fetch dependencies |
| `jq` | JSON parsing (`brew install jq`) — installer handles this |
| `terminal-notifier` | Click-to-focus support (`brew install terminal-notifier`) — installer handles this |

---

## Installation

### One-command install (recommended)

```bash
git clone https://github.com/DawnLck/claude-code-done-notifier.git
cd claude-code-done-notifier
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
   cp notify-done.sh ~/.claude/hooks/notify-done.sh
   chmod +x ~/.claude/hooks/notify-done.sh
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
               "command": "bash ~/.claude/hooks/notify-done.sh",
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
Stop hook fires → notify-done.sh receives JSON on stdin
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
    "NOTIFY_DONE_ONLY_WHEN_AWAY": "true"
  }
}
```

| Variable | Default | Description |
|---|---|---|
| `NOTIFY_DONE_LANG` | auto | Force language: `zh` or `en`. Auto-detects from `$LANG` if unset. |
| `NOTIFY_DONE_ONLY_WHEN_AWAY` | `"false"` | Set to `"true"` to suppress the notification when the originating terminal is already the frontmost app. |

---

## Troubleshooting

- **Notification doesn't appear**: Check System Settings → Notifications → terminal-notifier.
- **Click doesn't focus**: Verify `terminal-notifier` is installed.
- **Summary is generic**: The hook falls back to a locale-appropriate generic string if the transcript isn't ready.

---

# <a name="claude-code-done-notifier-zh"></a>claude-code-done-notifier (简体中文)

[English](#claude-code-done-notifier) | [简体中文](#claude-code-done-notifier-zh)

一个为 [Claude Code](https://claude.ai/code) 提供的 macOS 通知钩子，在 Claude 完成任务时触发。

**功能特性：**
- **显示 Claude 最后回复的第一句话** 作为通知主体 — 真正摘要了所做的工作。
- **显示会话时长和项目名称** 在副标题中。
- **点击通知激活对应的终端或编辑器窗口**，直接回到 Claude 运行的地方。
- **支持中英文双语** (自动检测或手动配置)。
- **播放 macOS 系统音 "Glass"**。
- **可选：焦点感知模式** — 如果你正在查看终端，则静默通知。
- **支持多种终端与编辑器**：Terminal, iTerm2, Warp, VS Code, Cursor, Hyper, Alacritty, kitty, Ghostty。

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

| 要求 | 说明 |
|---|---|
| macOS | 通知使用 macOS 原生 API |
| [Claude Code](https://claude.ai/code) | Anthropic 推出的 CLI 工具 |
| [Homebrew](https://brew.sh) | 安装脚本用于获取依赖 |
| `jq` | JSON 解析 (`brew install jq`) — 安装脚本会自动处理 |
| `terminal-notifier` | 点击跳转支持 (`brew install terminal-notifier`) — 安装脚本会自动处理 |

---

## 安装指南

### 一键安装 (推荐)

```bash
git clone https://github.com/DawnLck/claude-code-done-notifier.git
cd claude-code-done-notifier
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
    "NOTIFY_DONE_ONLY_WHEN_AWAY": "true"
  }
}
```

| 变量 | 默认值 | 描述 |
|---|---|---|
| `NOTIFY_DONE_LANG` | auto | 强制指定语言：`zh` 或 `en`。未设置时自动检测 `$LANG`。 |
| `NOTIFY_DONE_ONLY_WHEN_AWAY` | `"false"` | 设置为 `"true"` 时，如果所在的终端窗口已处于最前，则不发送通知。 |

---

## 故障排除

- **通知未出现**：检查 系统设置 → 通知 → 允许 terminal-notifier。
- **点击无法跳转**：确认已安装 `terminal-notifier`。
- **摘要内容为空**：如果钩子触发时日志尚未写入，会自动回退到本地化的通用文案。

---

## 参与贡献

欢迎提交 PR！改进方向：
- Linux 支持 (通过 `notify-send` / `libnotify`)
- 更多终端应用的检测支持

---

## 开源协议

MIT
