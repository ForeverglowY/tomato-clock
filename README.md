# TomatoClock

一个原生 macOS 菜单栏番茄钟：

- 默认专注 25 分钟、休息 5 分钟，可在菜单栏弹窗中修改
- 菜单栏实时显示剩余时间
- 专注和休息结束时播放系统提示音
- 每个阶段结束后只准备下一阶段，不会自动开始
- 本地记录当天专注和休息时长

## 运行

```bash
swift run TomatoClock
```

应用启动后不会出现在 Dock，在菜单栏点击 `🍅 25:00` 即可操作。

## 生成可双击的 App

```bash
./scripts/build-app.sh
```

生成结果位于 `dist/TomatoClock.app`，可以直接双击，或拖入“应用程序”文件夹。

应用图标源文件位于 `Assets/AppIcon.png`，打包使用的 macOS 图标为 `Assets/AppIcon.icns`。

## 构建检查

```bash
swift build
```
