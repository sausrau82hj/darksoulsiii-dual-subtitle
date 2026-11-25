# Dual Subtitle — *DARK SOULS III*

NPC dialogue and cutscene subtitles in Chinese and English, Chinese on top. Works the same in the
Chinese and the English game settings — the text and the order do not change with the language.
Text only.

| | |
| --- | --- |
| NPC dialogue | `中文` over `English` |
| Cutscene subtitles | `中文` over `English` |
| Area name shown after warping | English, in both language modes |

Base game and both DLC. Every other text stays vanilla.

**English** · [中文](#中文)

---

## English

### Install

Point one of the mod loaders at this package's folder (it holds `msg/` and `font/`) — [me](https://www.nexusmods.com/darksouls3/mods/2410), [me2](https://github.com/soulsmods/ModEngine2) or [me3](https://github.com/garyttierney/me3). Start the game offline.

### Uninstall

Delete the mod's folder.

### Notes

- Text only. If another mod also replaces `msg`, load order decides.
- `font/matissepron/font.gfx` is the Simplified Chinese font, put where the English setting looks for its font. That is what lets Chinese render in the English setting; English menu text is drawn with that font as well.
- The area title is drawn on one line and cannot be made bilingual without cutting the tail off long names, so it stays English.

---

## 中文

### 安装

用 [me](https://www.nexusmods.com/darksouls3/mods/2410)、[me2](https://github.com/soulsmods/ModEngine2)、[me3](https://github.com/garyttierney/me3) 其中一个指向本包的目录（里面是 `msg/` 和 `font/`）。装完离线启动。

### 卸载

删掉本包的目录。

### 注意

- 只改文本。别的 mod 也换 `msg` 时，看加载顺序。
- `font/matissepron/font.gfx` 是简体中文字体，放在英文设置读取字体的位置。英文设置下能显示中文靠的就是它；英文界面的文字也会用这套字体渲染。
- 地名标题是单行、不能缩字号，双语会把长名字的尾巴切掉，所以固定显示英文。

---

## Credits

Inspired by [ER-Dualsub-Tool](https://github.com/matyamod/ER-Dualsub-Tool).

---

## License

[LICENSE](LICENSE) (MIT) covers this README. It does not cover the game text under `msg/` or the font under `font/` (modified FromSoftware / Bandai Namco assets, offline single-player use only). Not affiliated with FromSoftware or Bandai Namco.
