# EmbedGrabTest — 嵌入式拉起 Grab 测试宿主

一个独立的鸿蒙元服务宿主 App，专门用于测试通过 `FullScreenLaunchComponent` 全屏嵌入拉起 Grab 的场景。

## 项目信息

| 字段 | 值 |
|------|------|
| bundleName | `com.atomicservice.5765880207855877209` |
| bundleType | atomicService |
| 目标 Grab appId | `5765880207856208787` |
| 目标 Grab bundleName | `com.atomicservice.5765880207856208787` |
| 最低 SDK | 5.0.0 (API 12) |

## 构建

```bash
cd D:\Documents\Codes\xnhz\1\EmbedGrabTest

"D:\Documents\Codes\ai\Sdk\openHarmony\tools\node\node.exe" ^
  "D:\Documents\Codes\ai\Sdk\openHarmony\tools\hvigor\bin\hvigorw.js" ^
  assembleHap --mode module -p product=default
```

产物路径：`entry\build\default\outputs\default\entry-default-signed.hap`

## 安装

```bash
hdc install -r entry\build\default\outputs\default\entry-default-signed.hap
```

## 测试功能说明

App 打开后进入 `EmbedGrabTestPage`，页面从上到下分为四个区域：

### ① 目标 Ability 选择

| 按钮 | 效果 |
|------|------|
| **指定 EmbedTestAbility** | 嵌入拉起时指定跳转到 Grab 的 `EmbedTestAbility` |
| **不指定(默认)** | 不传 abilityName，由 Grab 走默认入口 `EntryAbility` |

### ② 全屏嵌入拉起（核心测试项）

蓝色入口按钮，点击后通过 `FullScreenLaunchComponent` 全屏嵌入拉起 Grab。

拉起时自动传递的参数：
```
test_flag: 'embed_test'
from: 'AtomicPlatform'
isFullScreen: true
ability.params.targetAbilityName: <选择的Ability>  // 仅指定时传
abilityName: <选择的Ability>                       // 仅指定时传
```

### ③ 跳出式 startAbility（对照组）

普通跳出式拉起 Grab，用于对比嵌入式和跳出式的行为差异。

### ④ 日志面板

实时显示所有操作日志，包含时间戳，便于问题排查。

## 崩溃检测机制

App 内置了嵌入目标崩溃检测：

- 嵌入拉起后，如果在 **5 秒内**返回宿主，判定为疑似崩溃
- 检测到崩溃后显示恢复面板：
  - **重试嵌入**：最多重试 3 次
  - **跳出式打开**：降级为 `startAbility` 方式
  - **取消**：关闭错误提示

## 测试用例

### 1. 基本嵌入拉起

**前置条件**：设备已安装 Grab 元服务（graybox 包）

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 打开 EmbedGrabTest | 页面显示，状态指示灯为绿色"就绪" |
| 2 | 保持"不指定(默认)" | 目标显示 `默认(EntryAbility)` |
| 3 | 点击蓝色入口按钮 | 全屏嵌入拉起 Grab，进入 Grab 首页 |
| 4 | 在 Grab 内正常操作 | Grab 页面响应正常，无闪白/闪退 |
| 5 | 返回宿主 | 回到 EmbedGrabTest 页面，状态恢复"就绪" |

### 2. 指定 Ability 拉起

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 点击"指定 EmbedTestAbility" | 目标切换为 `EmbedTestAbility` |
| 2 | 点击蓝色入口按钮 | 嵌入拉起 Grab 并进入指定 Ability |
| 3 | 返回宿主 | 正常返回 |

### 3. 跳出式对照

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 点击"跳出式拉起 Grab" | 以 startAbility 方式跳转到 Grab |
| 2 | 日志面板 | 显示 `startAbility succeeded` |
| 3 | 返回宿主 | 正常返回 |

### 4. 崩溃检测与恢复

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 确保 Grab 未安装或版本不兼容 | — |
| 2 | 点击蓝色入口按钮 | 嵌入拉起后快速返回（<5秒） |
| 3 | 观察 | 状态变红，显示"嵌入启动失败"面板 |
| 4 | 点击"重试嵌入" | 重新显示入口按钮，可再次尝试 |
| 5 | 连续失败 3 次后 | "重试嵌入"按钮消失，提示跳出式打开 |
| 6 | 点击"跳出式打开" | 降级为 startAbility 拉起 |

### 5. 安全区验证

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 嵌入拉起 Grab 后 | Grab 页面内容不与状态栏/导航条重叠 |
| 2 | 对比跳出式拉起 | 两种方式的安全区表现一致 |

> **注意**：宿主 Ability 已设置 `setWindowLayoutFullScreen(true)`。
> 如果 Grab 侧的 `isFollowHostWindowMode` 判定逻辑有误，嵌入态下会出现内容贴边问题。

### 6. 生命周期日志

测试过程中关注日志面板中的生命周期事件：

| 事件 | 含义 |
|------|------|
| `embed launch #N` | 第 N 次嵌入拉起 |
| `page hidden while launching` | 嵌入成功，Grab 接管了画面 |
| `embed returned via tracker, elapsed=Xms` | Grab 退出，返回宿主 |
| `CRASH DETECTED` | 嵌入目标疑似崩溃 |
| `embed ended normally` | 正常结束 |

## 注意事项

1. **Grab 包类型**：测试时 Grab 需安装 **graybox + debug** 包（见 GrabMetaServices 的 `CLAUDE.md` 构建配置说明）
2. **签名**：本项目使用 `AtomicServeiceChujinTest` 调试签名，仅用于开发测试
3. **设备要求**：需要 HarmonyOS 5.0+ 设备
4. **USB 连接**：安装和调试需要 USB 连接设备，使用 `hdc list targets` 确认设备已连接
