#!/usr/bin/env python3
import os
import json
import urllib.parse
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading
import time

SETTINGS_FILE = os.path.expanduser("~/.claude/settings.json")
SOUNDS_DIR = os.path.expanduser("~/.claude/sounds")
PORT = int(os.environ.get("NOTIFY_CONFIG_PORT", "8888"))

HTML_CONTENT = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Notifier Configuration</title>
    <style>
        :root { --primary: #d97758; --primary-hover: #e0886c; --bg: #0f1115; --card-bg: rgba(255, 255, 255, 0.03); --border: rgba(255, 255, 255, 0.08); --accent-blue: #58a6d9; }
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif; background: var(--bg); color: #fff; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 40px 20px; box-sizing: border-box; overflow-x: hidden; }
        .bg-blob { position: fixed; width: 800px; height: 800px; background: radial-gradient(circle, rgba(217,119,88,0.12) 0%, rgba(0,0,0,0) 70%); top: -200px; right: -300px; z-index: 0; filter: blur(80px); pointer-events: none; }
        .bg-blob-2 { position: fixed; width: 600px; height: 600px; background: radial-gradient(circle, rgba(88,166,217,0.08) 0%, rgba(0,0,0,0) 70%); bottom: -200px; left: -200px; z-index: 0; filter: blur(80px); pointer-events: none; }
        
        .container { background: var(--card-bg); border: 1px solid var(--border); backdrop-filter: blur(40px); -webkit-backdrop-filter: blur(40px); border-radius: 32px; width: 100%; max-width: 520px; padding: 40px; position: relative; z-index: 1; box-shadow: 0 40px 100px rgba(0,0,0,0.6), inset 0 1px 0 rgba(255,255,255,0.05); transform: translateY(30px); opacity: 0; animation: springUp 0.8s cubic-bezier(0.17, 0.88, 0.32, 1.1) forwards; }
        @keyframes springUp { to { transform: translateY(0); opacity: 1; } }
        
        .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 32px; }
        .title-group { flex: 1; }
        .title { font-size: 28px; font-weight: 800; margin: 0 0 6px 0; letter-spacing: -0.8px; color: #fff; display: flex; align-items: center; gap: 12px; }
        .title svg { width: 32px; height: 32px; color: var(--primary); }
        .subtitle { font-size: 15px; color: #888; margin: 0; line-height: 1.5; }
        
        .lang-toggle { background: rgba(255,255,255,0.05); border: 1px solid var(--border); border-radius: 12px; padding: 6px 12px; color: #aaa; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 6px; }
        .lang-toggle:hover { background: rgba(255,255,255,0.1); color: #fff; }
        .lang-toggle.active { border-color: var(--primary); color: var(--primary); }

        .form-section { margin-bottom: 36px; border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 8px; }
        .form-section:last-of-type { border-bottom: none; }
        .section-title { font-size: 12px; text-transform: uppercase; letter-spacing: 1.5px; color: #555; font-weight: 700; margin-bottom: 16px; display: flex; align-items: center; gap: 8px; }
        .section-title::after { content: ""; flex: 1; height: 1px; background: rgba(255,255,255,0.03); }
        
        .form-group { display: flex; justify-content: space-between; align-items: center; padding: 18px 0; position: relative; }
        .form-group.col { flex-direction: column; align-items: flex-start; }
        .form-group.col > .label-container { margin-bottom: 12px; width: 100%; }
        
        .label-container { flex: 1; padding-right: 20px; }
        label { display: block; font-size: 15px; font-weight: 600; color: #eee; margin-bottom: 4px; }
        .help-text { font-size: 13px; color: #666; line-height: 1.4; }
        
        input[type="text"], input[type="password"], select { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 14px; color: #fff; padding: 12px 16px; font-size: 14px; width: 100%; box-sizing: border-box; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); outline: none; }
        input:focus, select:focus { background: rgba(255,255,255,0.08); border-color: var(--primary); box-shadow: 0 0 0 4px rgba(217,119,88,0.15); }
        
        .switch-container { position: relative; width: 48px; height: 26px; }
        .switch { position: absolute; inset: 0; appearance: none; background: rgba(255,255,255,0.08); border-radius: 20px; cursor: pointer; transition: background 0.3s cubic-bezier(0.4, 0, 0.2, 1); outline: none; border: 1px solid var(--border); }
        .switch::before { content: ""; position: absolute; width: 20px; height: 20px; background: #fff; border-radius: 50%; top: 2px; left: 2px; box-shadow: 0 2px 4px rgba(0,0,0,0.3); transition: transform 0.4s cubic-bezier(0.18, 0.89, 0.32, 1.28); }
        .switch:checked { background: var(--primary); border-color: transparent; }
        .switch:checked::before { transform: translateX(22px); }
        
        .sound-row { display: grid; grid-template-columns: 1fr 2fr auto; gap: 10px; width: 100%; margin-top: 4px; }
        .btn-icon { background: rgba(255,255,255,0.05); border: 1px solid var(--border); border-radius: 12px; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; cursor: pointer; transition: all 0.2s; color: #aaa; flex-shrink: 0; }
        .btn-icon:hover { background: rgba(255,255,255,0.12); color: #fff; transform: scale(1.05); }
        .btn-icon:active { transform: scale(0.95); }
        .btn-icon svg { width: 20px; height: 20px; }
        .btn-icon.play-btn { color: var(--accent-blue); border-color: rgba(88,166,217,0.2); }

        .form-footer { margin-top: 10px; display: flex; flex-direction: column; gap: 12px; }
        .btn-primary { background: linear-gradient(135deg, var(--primary) 0%, var(--primary-hover) 100%); color: white; border: none; border-radius: 20px; padding: 20px; font-size: 16px; font-weight: 700; width: 100%; cursor: pointer; transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); position: relative; overflow: hidden; display: flex; justify-content: center; align-items: center; box-shadow: 0 10px 30px rgba(217,119,88,0.25); }
        .btn-primary:hover { transform: translateY(-3px); box-shadow: 0 15px 35px rgba(217,119,88,0.35); }
        .btn-primary:active { transform: translateY(-1px); }
        
        .btn-secondary { background: rgba(255,255,255,0.03); color: #888; border: 1px solid var(--border); border-radius: 16px; padding: 12px; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.2s; text-align: center; }
        .btn-secondary:hover { background: rgba(255,255,255,0.08); color: #fff; }

        .success-overlay { position: absolute; inset: 0; background: rgba(10,12,16,0.98); z-index: 10; display: flex; flex-direction: column; align-items: center; justify-content: center; border-radius: 32px; opacity: 0; pointer-events: none; transform: scale(0.95); transition: all 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
        .success-overlay.show { opacity: 1; pointer-events: auto; transform: scale(1); }
        .checkmark-bg { width: 90px; height: 90px; background: rgba(217,119,88,0.1); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-bottom: 24px; }
        .checkmark-bg svg { width: 44px; height: 44px; color: var(--primary); stroke: currentColor; stroke-width: 3; fill: none; stroke-linecap: round; stroke-linejoin: round; stroke-dasharray: 60; stroke-dashoffset: 60; }
        .success-overlay.show svg { animation: drawCheck 0.6s 0.3s ease-in-out forwards; }
        @keyframes drawCheck { to { stroke-dashoffset: 0; } }
        
        .success-text { font-size: 24px; font-weight: 800; color: #fff; margin-bottom: 8px; letter-spacing: -0.5px; }
        .close-hint { font-size: 15px; color: #666; }
        
        .loading-initial { text-align: center; color: #555; position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 5; }
        .hide { display: none !important; visibility: hidden; }
        .invisible { opacity: 0; pointer-events: none; }
        
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 10px; }
    </style>
</head>
<body>
    <div class="bg-blob"></div>
    <div class="bg-blob-2"></div>

    <div class="container" id="app">
        <div class="header">
            <div class="title-group">
                <h1 class="title">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
                    </svg>
                    <span data-i18n="title">Notifier Settings</span>
                </h1>
                <p class="subtitle" data-i18n="subtitle">Customize your Claude Code notification experience.</p>
            </div>
            <button class="lang-toggle" id="langSwitcher" title="Switch Language">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
                <span id="langName">EN</span>
            </button>
        </div>

        <div id="loadingLayer" class="loading-initial"><div data-i18n="loading">Consulting manifest...</div></div>

        <form id="configForm" class="invisible" autocomplete="off">
            <div class="form-section">
                <div class="section-title" data-i18n="sec_general">General Preferences</div>
                
                <div class="form-group">
                    <div class="label-container">
                        <label for="away" data-i18n="label_away">Focus-aware Silence</label>
                        <div class="help-text" data-i18n="help_away">Suppress notifications if the terminal is currently frontmost</div>
                    </div>
                    <div class="switch-container">
                        <input type="checkbox" id="away" name="NOTIFY_ONLY_WHEN_AWAY" class="switch">
                    </div>
                </div>

                <div class="form-group row hide">
                    <select id="lang" name="NOTIFY_LANG">
                        <option value="">Auto</option>
                        <option value="en">EN</option>
                        <option value="zh">ZH</option>
                    </select>
                </div>
            </div>

            <div class="form-section">
                <div class="section-title" data-i18n="sec_display">Display Engine</div>
                
                <div class="form-group">
                    <div class="label-container">
                        <label for="summary" data-i18n="label_summary">AI Interaction Abstract</label>
                        <div class="help-text" data-i18n="help_summary">Distill Claude's verbosity into a concise single-sentence brief</div>
                    </div>
                    <div class="switch-container">
                        <input type="checkbox" id="summary" name="NOTIFY_SHOW_SUMMARY" class="switch">
                    </div>
                </div>
                
                <div class="form-group">
                    <div class="label-container">
                        <label for="duration" data-i18n="label_duration">Execution Telemetry</label>
                        <div class="help-text" data-i18n="help_duration">Append real-time task duration to the notification payload</div>
                    </div>
                    <div class="switch-container">
                        <input type="checkbox" id="duration" name="NOTIFY_SHOW_DURATION" class="switch">
                    </div>
                </div>

                <div class="form-group">
                    <div class="label-container">
                        <label for="project" data-i18n="label_project">Project Context</label>
                        <div class="help-text" data-i18n="help_project">Display the current working directory or Git repository name</div>
                    </div>
                    <div class="switch-container">
                        <input type="checkbox" id="project" name="NOTIFY_SHOW_PROJECT" class="switch">
                    </div>
                </div>
            </div>
            
            <div class="form-section">
                <div class="section-title" data-i18n="sec_sound">Haptic & Audio Feedback</div>
                
                <div class="form-group col">
                    <div class="label-container">
                        <label data-i18n="label_sound_notify">Status Pulse (Running)</label>
                        <div class="help-text" data-i18n="help_sound_notify">A subtle audio chime for status updates or user prompts</div>
                    </div>
                    <div class="sound-row">
                        <select class="preset-select" id="preset_notify"><option value="" data-i18n="opt_custom">Custom Path...</option></select>
                        <input type="text" id="sound_notify" name="NOTIFY_SOUND_NOTIFICATION" placeholder="/path/to/sound.wav">
                        <button type="button" class="btn-icon play-btn" id="test_notify" title="Preview Audio">
                            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                        </button>
                    </div>
                </div>

                <div class="form-group col">
                    <div class="label-container">
                        <label data-i18n="label_sound_stop">Completion Vibe (Success)</label>
                        <div class="help-text" data-i18n="help_sound_stop">Distinct audio celebration for successful task completion</div>
                    </div>
                    <div class="sound-row">
                        <select class="preset-select" id="preset_stop"><option value="" data-i18n="opt_custom">Custom Path...</option></select>
                        <input type="text" id="sound_stop" name="NOTIFY_SOUND_END" placeholder="/path/to/sound.wav">
                        <button type="button" class="btn-icon play-btn" id="test_stop" title="Preview Audio">
                            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                        </button>
                    </div>
                </div>
            </div>

            <div class="form-section">
                <div class="section-title" data-i18n="sec_advanced">Advanced Integrations</div>
                
                <div class="form-group col">
                    <div class="label-container">
                        <label for="feishu" data-i18n="label_feishu">Lark/Feishu Webhook</label>
                    </div>
                    <input type="password" id="feishu" name="NOTIFY_FEISHU_WEBHOOK_URL" placeholder="https://open.feishu.cn/open-apis/bot/v2/hook/...">
                </div>
                
                <div class="form-group col">
                    <div class="label-container">
                        <label for="llm_service" data-i18n="label_llm_service">AI Summary Service</label>
                        <div class="help-text" data-i18n="help_llm_service">Select the LLM backend used to distill Claude's replies</div>
                    </div>
                    <select id="llm_service" name="NOTIFY_LLM_SERVICE">
                        <option value="none" data-i18n="opt_llm_none">Disabled</option>
                        <option value="claude-code" data-i18n="opt_llm_cc">Claude Code (Built-in)</option>
                        <option value="custom-anthropic" data-i18n="opt_llm_ant">Custom — Anthropic</option>
                        <option value="custom-openai" data-i18n="opt_llm_oai">Custom — OpenAI-Compatible</option>
                    </select>
                </div>

                <div class="form-group col" id="row_llm_key">
                    <div class="label-container">
                        <label for="llm" data-i18n="label_llm">API Key</label>
                        <div class="help-text" data-i18n="help_llm">Authentication key for the chosen LLM provider</div>
                    </div>
                    <input type="password" id="llm" name="NOTIFY_LLM_API_KEY" placeholder="sk-ant-...">
                </div>

                <div class="form-group col" id="row_llm_endpoint">
                    <div class="label-container">
                        <label for="llm_endpoint" data-i18n="label_llm_endpoint">API Endpoint</label>
                        <div class="help-text" data-i18n="help_llm_endpoint">Leave blank to use the provider default</div>
                    </div>
                    <input type="text" id="llm_endpoint" name="NOTIFY_LLM_ENDPOINT" placeholder="https://api.openai.com/v1/chat/completions">
                </div>

                <div class="form-group col" id="row_llm_model">
                    <div class="label-container">
                        <label for="model" data-i18n="label_model">Model ID</label>
                    </div>
                    <input type="text" id="model" name="NOTIFY_LLM_MODEL" placeholder="claude-haiku-4-5-20251001">
                </div>
            </div>

            <div class="form-footer">
                <button type="submit" id="submitBtn" class="btn-primary">
                    <span data-i18n="btn_save">Apply & Sync Changes</span>
                </button>
                <button type="button" id="resetBtn" class="btn-secondary">
                    <span data-i18n="btn_reset">Reset Managed Settings</span>
                </button>
            </div>
        </form>

        <div class="success-overlay" id="successOverlay">
            <div class="checkmark-bg">
                <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
            </div>
            <div class="success-text" data-i18n="success_msg">Sync Complete</div>
            <div class="close-hint" data-i18n="success_hint">Security manifest updated. Service restarting.</div>
        </div>
    </div>

    <script>
        const i18n = {
            en: {
                title: 'Notifier Settings', subtitle: 'Refining your Claude Code haptic environment.', loading: 'Decrypting manifest...',
                sec_general: 'General Preferences', sec_display: 'Display Engine', sec_sound: 'Haptic & Audio', sec_advanced: 'Advanced Integrations',
                label_lang: 'Language', help_lang: 'Notification text localized language', opt_auto: 'Auto-detect', opt_custom: 'Custom Path...',
                label_away: 'Focus-aware', help_away: 'Silence prompts while terminal is focused',
                label_summary: 'AI Interaction', help_summary: 'Distill long replies into concise abstracts',
                label_duration: 'Execution Telemetry', help_duration: 'Include task duration in notifications',
                label_project: 'Project Context', help_project: 'Show repository or project name',
                label_sound_notify: 'Status Pulse', help_sound_notify: 'Audio feedback for running status',
                label_sound_stop: 'Completion Vibe', help_sound_stop: 'Celebratory cue for task success',
                label_feishu: 'Feishu Webhook',
                label_llm_service: 'AI Summary Service', help_llm_service: 'Select the LLM backend for reply distillation',
                opt_llm_none: 'Disabled', opt_llm_cc: 'Claude Code (Built-in)', opt_llm_ant: 'Custom — Anthropic', opt_llm_oai: 'Custom — OpenAI-Compatible',
                label_llm: 'API Key', help_llm: 'Authentication key for the chosen LLM provider',
                label_llm_endpoint: 'API Endpoint', help_llm_endpoint: 'Leave blank to use the provider default',
                label_model: 'Model ID', btn_save: 'Apply & Sync Changes', btn_reset: 'Reset to System Defaults',
                success_msg: 'Sync Complete', success_hint: 'Security manifest updated. Service restarting.'
            },
            zh: {
                title: '通知功能设置', subtitle: '极致简约，只为捕捉每一次灵感火花。', loading: '正在检索配置...',
                sec_general: '常规偏好', sec_display: '内容展示引擎', sec_sound: '触觉与音效反馈', sec_advanced: '高级集成',
                label_lang: '语言', help_lang: '通知正文展示语言', opt_auto: '自动检测', opt_custom: '自定义路径...',
                label_away: '焦点感知模式', help_away: '仅在离开终端窗口时发出提醒',
                label_summary: 'AI 交互摘要', help_summary: '智能提炼 Claude 回复的核心直觉',
                label_duration: '执行遥测数据', help_duration: '在通知副标题中显示任务耗时',
                label_project: '项目上下文', help_project: '显示当前工作的项目或目录名',
                label_sound_notify: '交互等待 (运行中)', help_sound_notify: '有进度更新或需要交互时的轻量音效',
                label_sound_stop: '完成反馈 (成功)', help_sound_stop: '任务圆满成功时的仪式感音效',
                label_feishu: '飞书/Lark Webhook',
                label_llm_service: 'AI 摘要服务', help_llm_service: '选择用于提炼回复的 LLM 后端',
                opt_llm_none: '已禁用', opt_llm_cc: 'Claude Code（内置）', opt_llm_ant: '自定义 — Anthropic', opt_llm_oai: '自定义 — OpenAI 兼容',
                label_llm: 'API 密钥', help_llm: '所选 LLM 提供商的认证密钥',
                label_llm_endpoint: 'API 端点', help_llm_endpoint: '留空则使用提供商默认地址',
                label_model: '模型标识符', btn_save: '同步并应用更改', btn_reset: '重置为系统默认',
                success_msg: '同步已完成', success_hint: '配置已安全存入系统，正在重启服务。'
            }
        };

        let currentLang = 'en';

        function updateUI(lang) {
            currentLang = lang;
            const l = i18n[lang] || i18n.en;
            document.querySelectorAll('[data-i18n]').forEach(el => {
                const key = el.getAttribute('data-i18n');
                if (l[key]) el.innerText = l[key];
            });
            document.getElementById('langName').innerText = lang.toUpperCase();
            document.getElementById('lang').value = (lang === (navigator.language.startsWith('zh') ? 'zh' : 'en')) ? '' : lang;
        }

        async function playAudio(path) {
            if (!path) return;
            try {
                const audio = new Audio(`/api/sound-file?path=${encodeURIComponent(path)}`);
                await audio.play();
            } catch (err) { console.error("Audio playback interrupted", err); }
        }

        document.getElementById('langSwitcher').addEventListener('click', () => {
            const next = currentLang === 'en' ? 'zh' : 'en';
            updateUI(next);
        });

        document.addEventListener('DOMContentLoaded', async () => {
            const form = document.getElementById('configForm');
            const loading = document.getElementById('loadingLayer');
            const presetNotify = document.getElementById('preset_notify');
            const presetStop = document.getElementById('preset_stop');
            const inputNotify = document.getElementById('sound_notify');
            const inputStop = document.getElementById('sound_stop');

            try {
                const [cfgRes, sndRes] = await Promise.all([fetch('/api/config'), fetch('/api/sounds')]);
                const env = await cfgRes.json();
                const sounds = await sndRes.json();
                
                sounds.forEach(s => {
                    presetNotify.add(new Option(s.name, s.path));
                    presetStop.add(new Option(s.name, s.path));
                });

                const sync = (sel, inp) => {
                    const match = Array.from(sel.options).find(o => o.value === inp.value);
                    if (match) sel.value = match.value;
                    sel.onchange = () => { 
                        if(sel.value) {
                            inp.value = sel.value;
                            playAudio(sel.value); // Auto-play feedback
                        }
                    };
                    inp.oninput = () => {
                        const m = Array.from(sel.options).find(o => o.value === inp.value);
                        sel.value = m ? m.value : "";
                    };
                };

                const set = (name, val, isSwitch=false) => {
                    const el = form.elements[name]; if(!el) return;
                    if(isSwitch) el.checked = (val==='true' || val===true);
                    else el.value = val || '';
                };

                set('NOTIFY_LANG', env.NOTIFY_LANG);
                set('NOTIFY_SHOW_SUMMARY', env.NOTIFY_SHOW_SUMMARY !== 'false', true);
                set('NOTIFY_SHOW_DURATION', env.NOTIFY_SHOW_DURATION !== 'false', true);
                set('NOTIFY_SHOW_PROJECT', env.NOTIFY_SHOW_PROJECT !== 'false', true);
                set('NOTIFY_ONLY_WHEN_AWAY', env.NOTIFY_ONLY_WHEN_AWAY === 'true', true);
                set('NOTIFY_FEISHU_WEBHOOK_URL', env.NOTIFY_FEISHU_WEBHOOK_URL);
                set('NOTIFY_LLM_SERVICE', env.NOTIFY_LLM_SERVICE || 'none');
                set('NOTIFY_LLM_API_KEY', env.NOTIFY_LLM_API_KEY);
                set('NOTIFY_LLM_ENDPOINT', env.NOTIFY_LLM_ENDPOINT);
                set('NOTIFY_LLM_MODEL', env.NOTIFY_LLM_MODEL);
                updateLlmRows(env.NOTIFY_LLM_SERVICE || 'none');
                
                // Prioritize specific sound keys, fallback to generic
                const sNotify = env.NOTIFY_SOUND_NOTIFICATION || env.NOTIFY_SOUND_FILE;
                const sStop = env.NOTIFY_SOUND_END || env.NOTIFY_SOUND_FILE;
                set('NOTIFY_SOUND_NOTIFICATION', sNotify || '');
                set('NOTIFY_SOUND_END', sStop || '');

                sync(presetNotify, inputNotify);
                sync(presetStop, inputStop);

                const detected = env.NOTIFY_LANG || (navigator.language.startsWith('zh') ? 'zh' : 'en');
                updateUI(detected);
                
                loading.classList.add('hide');
                form.classList.remove('invisible');
            } catch (err) { loading.innerText = "Security Manifest Unavailable."; }

            function updateLlmRows(svc) {
                const needsKey      = svc === 'custom-anthropic' || svc === 'custom-openai';
                const needsEndpoint = svc === 'custom-openai' || svc === 'custom-anthropic';
                const needsModel    = svc !== 'none';
                document.getElementById('row_llm_key').style.display      = needsKey      ? '' : 'none';
                document.getElementById('row_llm_endpoint').style.display = needsEndpoint ? '' : 'none';
                document.getElementById('row_llm_model').style.display    = needsModel    ? '' : 'none';
            }
            document.getElementById('llm_service').onchange = (e) => updateLlmRows(e.target.value);

            document.getElementById('test_notify').onclick = () => playAudio(inputNotify.value);
            document.getElementById('test_stop').onclick = () => playAudio(inputStop.value);

            document.getElementById('resetBtn').onclick = () => {
                if(!confirm(currentLang === 'zh' ? '确定要重置所有托管配置吗？' : 'Reset all managed configurations to system defaults?')) return;
                form.reset();
                sync(presetNotify, inputNotify);
                sync(presetStop, inputStop);
            };

            form.onsubmit = async (e) => {
                e.preventDefault();
                const btn = document.getElementById('submitBtn');
                btn.innerText = currentLang === 'zh' ? '正在加速写入...' : 'Decrypting & Syncing...';
                
                const data = {};
                Array.from(form.elements).forEach(el => {
                    if(!el.name) return;
                    data[el.name] = el.type==='checkbox' ? (el.checked?'true':'false') : el.value;
                });

                try {
                    await fetch('/api/config', { method: 'POST', body: JSON.stringify(data) });
                    setTimeout(() => {
                        document.getElementById('successOverlay').classList.add('show');
                        setTimeout(() => fetch('/api/shutdown', {method:'POST'}), 1000);
                    }, 600);
                } catch(e) { alert("Security manifest update failed."); btn.innerText = "Error"; }
            };
        });
    </script>
</body>
</html>
"""

class ConfigHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/config':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            data = {}
            if os.path.exists(SETTINGS_FILE):
                try:
                    with open(SETTINGS_FILE, 'r') as f: data = json.load(f)
                except: pass
            self.wfile.write(json.dumps(data.get('env', {})).encode('utf-8'))
            return

        if self.path == '/api/sounds':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            sounds = []
            if os.path.exists(SOUNDS_DIR):
                for f in sorted(os.listdir(SOUNDS_DIR)):
                    if f.endswith(('.wav', '.mp3', '.aiff', '.m4a')):
                        sounds.append({"name": f, "path": os.path.join(SOUNDS_DIR, f)})
            self.wfile.write(json.dumps(sounds).encode('utf-8'))
            return

        if self.path.startswith('/api/sound-file'):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            path = params.get('path', [None])[0]
            if path and os.path.exists(path):
                self.send_response(200)
                mime = 'audio/wav'
                if path.endswith('.mp3'): mime = 'audio/mpeg'
                elif path.endswith('.aiff'): mime = 'audio/x-aiff'
                elif path.endswith('.m4a'): mime = 'audio/mp4'
                self.send_header('Content-Type', mime)
                self.end_headers()
                with open(path, 'rb') as f: self.wfile.write(f.read())
                return
            self.send_error(404)
            return

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(HTML_CONTENT.encode('utf-8'))

    def do_POST(self):
        if self.path == '/api/config':
            length = int(self.headers.get('Content-Length', 0))
            new_env = json.loads(self.rfile.read(length).decode('utf-8'))
            
            data = {}
            if os.path.exists(SETTINGS_FILE):
                try:
                    with open(SETTINGS_FILE, 'r') as f: data = json.load(f)
                except: pass
            
            if 'env' not in data: data['env'] = {}
            
            managed_keys = [
                'NOTIFY_LANG', 'NOTIFY_SHOW_SUMMARY', 'NOTIFY_SHOW_DURATION', 'NOTIFY_SHOW_PROJECT',
                'NOTIFY_ONLY_WHEN_AWAY', 'NOTIFY_FEISHU_WEBHOOK_URL',
                'NOTIFY_LLM_SERVICE', 'NOTIFY_LLM_API_KEY', 'NOTIFY_LLM_MODEL', 'NOTIFY_LLM_ENDPOINT',
                'NOTIFY_SOUND_NOTIFICATION', 'NOTIFY_SOUND_END', 'NOTIFY_SOUND_FILE'
            ]
            
            for k in managed_keys:
                if k in new_env:
                    val = new_env[k]
                    if val is None or val == '':
                        if k in data['env']: del data['env'][k]
                    else:
                        data['env'][k] = val
            
            os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
            with open(SETTINGS_FILE, 'w') as f: json.dump(data, f, indent=2)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
            return

        if self.path == '/api/shutdown':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status": "shutting down"}')
            def kill(): time.sleep(0.5); self.server.shutdown()
            threading.Thread(target=kill, daemon=True).start()
            return

    def log_message(self, format, *args): pass

def run():
    print(f"✨ Web Configuration Console initialized on port {PORT}")
    try:
        server = HTTPServer(('', PORT), ConfigHandler)
        server.serve_forever()
    except KeyboardInterrupt:
        print("\\nProcess interrupted. Server shut down.")
        
if __name__ == '__main__':
    run()
