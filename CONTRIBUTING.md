# Contributing to claude-code-notifier

[English](#contributing-to-claude-code-notifier) | [简体中文](#参与贡献-claude-code-notifier)

---

## Contributing to claude-code-notifier

Thank you for your interest in contributing! This is a macOS notification hook for Claude Code, and contributions of all kinds are welcome.

### Ways to Contribute

- **Bug reports** — open an issue with reproduction steps and your macOS/shell version
- **Feature requests** — open an issue describing the use case
- **Code contributions** — fix a bug, add a feature, or improve the docs via a pull request
- **Translations** — help improve Chinese/English copy or add new locales

### Development Setup

No build step required. The project is a single shell script (`claude-code-notify.sh`) and an installer (`install.sh`).

```bash
git clone https://github.com/DawnLck/claude-code-notifier.git
cd claude-code-notifier
```

Dependencies for local testing:

```bash
brew install jq terminal-notifier
```

To test the hook manually, pipe a sample JSON payload:

```bash
echo '{"session_id":"test-123"}' | bash claude-code-notify.sh
```

### Pull Request Guidelines

1. **Fork** the repo and create a branch from `main`.
2. Keep changes focused — one fix or feature per PR.
3. Test on macOS with at least one supported terminal (Terminal, iTerm2, Warp, VS Code, or Cursor).
4. If you touch user-facing strings, update both `en` and `zh` variants in `claude-code-notify.sh`.
5. Update `README.md` if your change affects configuration, installation, or behavior.
6. Open the PR against `main` with a clear title and description.

### Reporting Bugs

Please include:

- macOS version
- Shell (`bash`/`zsh`) and version
- Terminal app
- The exact notification that did or didn't appear
- Any relevant output from running the script manually

### Code Style

- Shell: POSIX-compatible `bash`, 2-space indentation
- Variable names: `UPPER_SNAKE_CASE` for env vars, `lower_snake_case` for locals
- Keep the script self-contained — no new external dependencies without discussion

### Roadmap / Good First Issues

- Linux support via `notify-send` / `libnotify`
- Support for more terminal emulators
- Tests for the transcript-parsing logic

### License

By contributing you agree that your work will be released under the [MIT License](./LICENSE).

---

## 参与贡献 claude-code-notifier

[English](#contributing-to-claude-code-notifier) | [简体中文](#参与贡献-claude-code-notifier)

感谢你有意愿为本项目贡献！这是一个面向 Claude Code 的 macOS 通知钩子，欢迎任何形式的贡献。

### 贡献方式

- **反馈 Bug** — 提交 Issue，附上复现步骤及 macOS / Shell 版本信息
- **功能建议** — 提交 Issue，描述使用场景
- **代码贡献** — 修复 Bug、新增功能或改进文档，通过 Pull Request 提交
- **翻译改进** — 帮助优化中英文文案，或添加其他语言支持

### 本地开发

本项目无需构建步骤，核心是一个 Shell 脚本（`claude-code-notify.sh`）和安装脚本（`install.sh`）。

```bash
git clone https://github.com/DawnLck/claude-code-notifier.git
cd claude-code-notifier
```

本地测试所需依赖：

```bash
brew install jq terminal-notifier
```

手动测试钩子，传入示例 JSON 载荷：

```bash
echo '{"session_id":"test-123"}' | bash claude-code-notify.sh
```

### Pull Request 规范

1. **Fork** 本仓库，从 `main` 分支创建你的功能分支。
2. 保持变更聚焦 — 每个 PR 只做一件事（修复或功能）。
3. 在 macOS 上使用至少一种支持的终端（Terminal、iTerm2、Warp、VS Code 或 Cursor）进行测试。
4. 如涉及用户可见的文字，需同步更新 `claude-code-notify.sh` 中的 `en` 和 `zh` 两套文案。
5. 如变更影响配置、安装方式或行为，请一并更新 `README.md`。
6. PR 请提交至 `main` 分支，标题和描述要清晰明了。

### 反馈 Bug

请在 Issue 中提供以下信息：

- macOS 版本
- Shell 类型（`bash`/`zsh`）及版本
- 使用的终端应用
- 期望出现的通知与实际情况的对比
- 手动运行脚本时的输出（如有）

### 代码风格

- Shell：兼容 POSIX 的 `bash`，缩进使用 2 个空格
- 变量命名：环境变量用 `UPPER_SNAKE_CASE`，局部变量用 `lower_snake_case`
- 保持脚本自包含 — 不得在未经讨论的情况下引入新的外部依赖

### 路线图 / 适合新手的 Issue

- Linux 支持（通过 `notify-send` / `libnotify`）
- 支持更多终端模拟器
- 为日志解析逻辑添加测试用例

### 开源协议

提交贡献即表示你同意将相关代码以 [MIT 许可证](./LICENSE) 发布。
