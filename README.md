# 长明 Eternal Light

A tiny macOS menu-bar app that keeps your Mac awake — really awake, lid closed included — with one click.

一个极小的 macOS 菜单栏应用：一键让 Mac 真正不睡，合盖也不睡。

**名字由来**：长明灯是中国古代佛前、陵寝中长年不熄的灯 — 灯不灭，人不睡。这个工具守的就是这一件事。

## 它做什么

macOS 自带的「防睡眠」设置只能防闲置睡眠，**合盖照样睡**。长明直接切换系统级的 `pmset disablesleep` 开关：

- **常开模式**：闲置不睡、合盖不睡、显示器可单独熄灭，机器保持可远程接入
- **正常模式**：恢复系统默认睡眠行为

适合的场景：远程办公时让家里的 Mac 随时可连、跑长任务、做家庭服务器、下载大文件过夜。

## 界面

- 菜单栏只有一朵小火焰，**没有文字**：单色模板图随系统菜单栏深浅自动适配 — 常开时是实心火焰，焰尖带缓慢的摇曳动效；正常模式是同一火焰的 35% 淡影
- 点小灯弹出小面板：当前状态、场景说明、一个大切换按钮
- 切换时系统弹窗输入管理员密码（`pmset` 需要管理员权限），切换成功后发一条系统通知
- 状态每 3 秒与系统实际值同步 — 在别处改了开关，图标会自己跟上

## 系统要求

- macOS 13 或更高（在 macOS 26 上开发与测试）
- 构建需要 Xcode Command Line Tools（`swiftc`、`iconutil`、`sips`）
- 切换开关时需要管理员密码

## 安装

```bash
git clone https://github.com/ranzong-ai/EternalLight.git
cd EternalLight
./install.sh
```

`install.sh` 会先调用 `build.sh` 构建 `长明.app`，装到 `/Applications/` 并启动一次；应用通过 SMAppService 自行注册为登录项，在「系统设置 → 通用 → 登录时打开」里以自己的名字和图标显示。首次启动会请求一次通知授权，允许后切换状态才有通知回执。

只构建不安装：`./build.sh`，产物是仓库目录下的 `长明.app`。

## 卸载

```bash
./uninstall.sh
```

注意：卸载不会改变当前睡眠设置。若在常开模式下卸载，手动恢复：`sudo pmset disablesleep 0`。

## 四种场景对照

| 场景 | 正常模式 | 常开模式 |
|---|---|---|
| 开盖 + 接电源 | 不睡（系统默认接电源不睡） | 不睡 |
| 开盖 + 电池 | 闲置约 1 分钟后睡 | 不睡（持续耗电） |
| 合盖 + 接电源 | 立刻睡 | **不睡** ← 核心场景 |
| 合盖 + 电池 | 立刻睡 | 不睡（电量有限，不建议装包里，散热差） |

关机状态下任何软件都无法远程开机，本工具也不例外。

## 安全说明

- 切换走的是系统自带 `pmset` 命令 + 系统管理员授权弹窗，不保存、不经手你的密码
- 那个密码弹窗是 macOS 的老式授权框，**不支持 Touch ID** — 这是系统限制，不是应用缺陷
- 应用是 ad-hoc 签名（无开发者证书），首次打开时系统可能提示确认来源，属正常现象，不是病毒警告
- 常开意味着机器在网络上更长时间可达；远程接入的安全仍由你自己的 SSH 密钥、防火墙等设置负责

## 和同类工具的区别

| | 长明 Eternal Light | KeepingYouAwake | Amphetamine |
|---|---|---|---|
| 原理 | 系统级 `disablesleep` | `caffeinate` | 电源断言 + 增强组件 |
| 合盖不睡 | ✅ 原生支持 | ❌ | 需额外组件 |
| 菜单栏显示 | 单色火焰（实心/35% + 摇曳动效） | 图标 | 图标 |
| 定时/触发器/计划 | ❌ 只做手动一键 | 部分 | ✅ 丰富 |
| 代码量 | 约 200 行 Swift，零依赖 | — | 闭源 |

长明只做一件事，把它做小、做透。

## 项目结构

```
.
├── README.md
├── LICENSE            # MIT
├── build.sh           # 构建 长明.app
├── install.sh         # 安装并首次启动（应用自注册登录项）
├── uninstall.sh
└── src/
    ├── main.swift         # 全部源码（菜单栏、面板、动画、通知）
    ├── Info.plist
    ├── AppIcon-1024.png.b64          # 应用图标（base64 文本存放）
    └── menubar_*.png.b64             # 菜单栏图标与动画帧（base64）
```

图标以 base64 文本形式存放，是为了让仓库能通过纯文本通道完整同步；`build.sh` 会自动解码。

## 开发说明

- 纯 AppKit + UserNotifications，无第三方依赖，`swiftc -swift-version 5` 直接编译
- 状态读取：每 3 秒解析 `pmset -g` 输出中的 `SleepDisabled` 值
- 图标设计：一朵丰盈的矢量火焰，焰芯是一弯留白月牙（外焰为日、内芯为月，日月为明），色板取中国传统色 — 底鱼肚白 #f7f4ed、焰身琥珀黄 #feba07 → 杏黄 #f28e16 → 落霞红 #cf4813（色值据 jufjzq/Chinese-Traditional-Colors 数据集）
- 摇曳动效：菜单栏模板图 3 帧焰尖位移以 0.45 秒间隔循环（0→1→2→1）；状态只用一个变量编码（实心 vs 35% 不透明度）
- 已知取舍：切换依赖 `NSAppleScript` 执行管理员命令，简单直接；未做 XPC 辅助进程

## License

MIT © 2026 ranzong-ai
