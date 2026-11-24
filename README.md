# Dual Subtitle — *DARK SOULS III*

Chinese and English in one line: `中文 / English`. Text only.

**English** · [中文](#中文)

---

## English

### Install

Point one of the mod loaders at this package's `msg` folder — [me](https://www.nexusmods.com/darksouls3/mods/2410), [me2](https://github.com/soulsmods/ModEngine2) or [me3](https://github.com/garyttierney/me3). Start the game offline.

### Rebuild

Windows PowerShell (built in) and [Yabber](https://github.com/JKAnderson/Yabber/releases) extracted anywhere under the package root.

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

Defaults: reads `source\`, writes `msg\`. Options only when needed: `-Source` / `-Out`, `-Game`, `-Yabber`, `-Primary` / `-Secondary`, `-Filter "menu*"`, `-KeepWork`.

`tools\dualsub.config.json`:

- `primary` / `secondary` — display language and the one appended to it, default `zhocn` / `engus`.
- `separator` — separator inside one line, default `" / "`.
- `categories` — `true` merge · `"off"` leave as-is · `"sec_only"` secondary only.
- `files` — per-pack and per-FMG overrides, highest priority.

Text that already wraps keeps its newline.

### Notes

- If another mod also replaces `msg`, put its files in `source\` and rebuild.
- A merged line can wrap to three lines and sit tight against the bottom of the dialogue box.

---

## 中文

### 安装

用 [me](https://www.nexusmods.com/darksouls3/mods/2410)、[me2](https://github.com/soulsmods/ModEngine2)、[me3](https://github.com/garyttierney/me3) 其中一个指向本包的 `msg`。装完离线启动。

### 重新生成

Windows 自带的 PowerShell，加上 [Yabber](https://github.com/JKAnderson/Yabber/releases)，解压到包内任意位置即可。

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

默认读包里的 `source\`、写回包里的 `msg\`。要换路径或只重建一部分时才加参数：`-Source` / `-Out`、`-Game`、`-Yabber`、`-Primary` / `-Secondary`、`-Filter "menu*"`、`-KeepWork`。

`tools\dualsub.config.json`：

- `primary` / `secondary` — 主语言与跟在后面的副语言，默认 `zhocn` / `engus`。
- `separator` — 单行内的分隔符，默认 `" / "`。
- `categories` — `true` 合并 · `"off"` 原样 · `"sec_only"` 只留副语言。
- `files` — 按包、按 FMG 覆盖，优先级最高。

原本带换行的文本固定保留换行。

### 注意

- 别的 mod 也换 `msg` 时，把它的文件放进 `source\` 再生成。
- 合并后的行可能折到三行，个别对话会顶到对话框下沿。

---

## Credits

Inspired by [ER-Dualsub-Tool](https://github.com/matyamod/ER-Dualsub-Tool).

---

## License

[LICENSE](LICENSE) (MIT) covers the files written for this project — `tools/dualsub.ps1`, its config, this README. It does not cover the game text under `msg/` and `source/` (modified FromSoftware / Bandai Namco text, offline single-player use only). Not affiliated with FromSoftware or Bandai Namco.
