# Dual Subtitle — *DARK SOULS III*

Chinese and English in one line: `中文 / English`. Text only — no gameplay, balance or asset changes.

**English** · [中文](#中文)

---

## English

### Install

- Place the `msg` folder from this package into the override directory used by your mod loader—point one of the following tools to it: [me](https://www.nexusmods.com/darksouls3/mods/2410), [me2](https://github.com/soulsmods/ModEngine2), or [me3](https://github.com/garyttierney/me3).
- Alternatively, unpack the game files using UXM or Nuxe, then overwrite the `Game\msg` directory. Once installed, launch the game in offline mode.

### Rebuild

Windows PowerShell (built in) and [Yabber](https://github.com/JKAnderson/Yabber/releases) extracted anywhere under the package root.

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

Defaults: reads `source\`, writes `msg\`.

- `-Source` / `-Out` — other folders.
- `-Game` — game folder, auto-detected otherwise.
- `-Yabber` — Yabber outside the package root.
- `-Primary` / `-Secondary` — swap the main and secondary language.
- `-Filter "menu*"` — matching packs only.
- `-KeepWork` — keep the intermediate files.

`tools\dualsub.config.json`:

- `primary` / `secondary` — display language and the one appended to it, default `zhocn` / `engus`.
- `separator` — separator inside one line, default `" / "`.
- `categories` — `true` merge · `"off"` leave as-is · `"sec_only"` secondary only.
- `files` — per-pack and per-FMG overrides, highest priority.

Text that already wraps keeps its newline.

### Known limitations

- Text only: if another mod also replaces `msg`, put its files in `source\` and rebuild.
- A merged line can wrap to three lines and sit tight against the bottom of the dialogue box.

### Finer edits

[WitchyBND](https://github.com/ividyon/WitchyBND/releases): unpack one pack, edit entries, repack.

---

## 中文

### 安装

- 把本包的 `msg` 放到你所用加载器的覆盖位置：用 [me](https://www.nexusmods.com/darksouls3/mods/2410) [me2](https://github.com/soulsmods/ModEngine2) [me3](https://github.com/garyttierney/me3) 其中一个指向它。
- 或者先用 UXM / Nuxe 解包、再覆盖 `Game\msg`。装完离线启动。

### 重新生成

Windows 自带的 PowerShell，加上 [Yabber](https://github.com/JKAnderson/Yabber/releases)，解压到包内任意位置即可，不用装 Python：

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

默认读包里的 `source\`、写回包里的 `msg\`。

- `-Source` / `-Out` — 换目录。
- `-Game` — 游戏目录，默认自动查找。
- `-Yabber` — Yabber 不在包内时。
- `-Primary` / `-Secondary` — 换主副语言。
- `-Filter "menu*"` — 只重建匹配的包。
- `-KeepWork` — 保留中间文件。

`tools\dualsub.config.json`：

- `primary` / `secondary` — 主语言与跟在后面的副语言，默认 `zhocn` / `engus`。
- `separator` — 单行内的分隔符，默认 `" / "`。
- `categories` — `true` 合并 · `"off"` 原样 · `"sec_only"` 只留副语言。
- `files` — 按包、按 FMG 覆盖，优先级最高。

原本带换行的文本固定保留换行。

### 已知限制

- 只改文本；别的 mod 也换 `msg` 时，把它的文件放进 `source\` 再生成。
- 合并后的行可能折到三行，个别对话会顶到对话框下沿。

### 更精细的修改

[WitchyBND](https://github.com/ividyon/WitchyBND/releases)：单独解包一个包，改完重新打包。

---

## Credits

Inspired by [ER-Dualsub-Tool](https://github.com/matyamod/ER-Dualsub-Tool).

---

## License

[LICENSE](LICENSE) (MIT) covers the files written for this project — `tools/dualsub.ps1`, its config, this README. It does not cover the game text under `msg/` and `source/` (modified FromSoftware / Bandai Namco text, offline single-player use only). Not affiliated with FromSoftware or Bandai Namco.
