import { FullScreenLaunchComponent } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';

const TAG = 'EmbedGrabTestPage';
const DOMAIN = 0xA002;
const GRAB_APP_ID = '5765880207856208787';
const GRAB_BUNDLE = 'com.atomicservice.5765880207856208787';
const EVENT_STANDALONE_ACTIVE = 'grab.standalone.active';
const EVENT_STANDALONE_CLEARED = 'grab.standalone.cleared';
const EMBED_ORIGIN_KEY = 'grab.embed.origin';
const EMBED_SESSION_ID_KEY = 'grab.embed.sessionId';

@Entry
@ComponentV2
struct EmbedGrabTestPage {
  @Local targetAbility: string = '';
  @Local logOutput: string = '';
  @Local embedSessionId: string = '';
  /** 监听独立 Grab 发来的"关闭嵌入面板"信号——为 true 时不渲染 FullScreenLaunchComponent */
  @Local embedDismissed: boolean = false;
  private subscriber?: commonEventManager.CommonEventSubscriber;
  /** 宿主侧乱序保护：记录最近一次已生效事件时间戳 */
  private lastAppliedTs: number = 0;
  /** 宿主侧反跳保护：记录最近一次 cleared 的会话 */
  private lastClearedSessionKey: string = '';

  log(msg: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', msg);
    this.logOutput = `[${new Date().toLocaleTimeString()}] ${msg}\n` + this.logOutput;
  }

  aboutToAppear(): void {
    this.log('page ready');
    this.subscribeStandaloneEvents();
  }

  aboutToDisappear(): void {
    this.unsubscribeStandaloneEvents();
  }

  onPageShow(): void {
    this.log('onPageShow');
  }

  onPageHide(): void {
    this.log('onPageHide');
  }

  /** 订阅独立 Grab 协调事件——收到 active 时关闭嵌入面板 */
  subscribeStandaloneEvents(): void {
    const info: commonEventManager.CommonEventSubscribeInfo = {
      events: [EVENT_STANDALONE_ACTIVE, EVENT_STANDALONE_CLEARED],
      // 仅接受来自 Grab 的事件，防止第三方 app 伪造 active/cleared 事件
      publisherBundleName: GRAB_BUNDLE
    };
    commonEventManager.createSubscriber(info).then((sub) => {
      this.subscriber = sub;
      commonEventManager.subscribe(sub, (err, data) => {
        if (err) {
          this.log('subscribe err: ' + JSON.stringify(err));
          return;
        }
        this.handleStandaloneEvent(data);
      });
      this.log('subscribed to standalone events');
    }).catch((e: BusinessError) => {
      this.log('createSubscriber failed: ' + JSON.stringify(e));
    });
  }

  unsubscribeStandaloneEvents(): void {
    if (!this.subscriber) {
      return;
    }
    commonEventManager.unsubscribe(this.subscriber, (err) => {
      if (err) {
        this.log('unsubscribe failed: ' + JSON.stringify(err));
        return;
      }
      this.log('unsubscribed');
    });
    this.subscriber = undefined;
  }

  handleStandaloneEvent(data: commonEventManager.CommonEventData): void {
    const event: string = data?.event ?? '';
    const params: Record<string, Object> = data?.parameters ?? {};
    this.log('received ' + event + ' params=' + JSON.stringify(params));
    const publishTs: number = this.readNumber(params['publishTs']);
    const processLaunchId: string = String(params['processLaunchId'] ?? '');
    const sessionId: string = String(params['sessionId'] ?? '');
    const sessionKey: string = sessionId.length > 0 ? sessionId : processLaunchId;
    if (publishTs > 0 && publishTs < this.lastAppliedTs) {
      this.log('drop stale event event=' + event + ' publishTs=' + publishTs + ' lastAppliedTs=' + this.lastAppliedTs);
      return;
    }
    if (event === EVENT_STANDALONE_ACTIVE) {
      if (sessionKey.length > 0 && sessionKey === this.lastClearedSessionKey) {
        this.log('drop rebound active after cleared sessionKey=' + sessionKey);
        return;
      }
      this.embedDismissed = true;
      if (publishTs > 0) {
        this.lastAppliedTs = publishTs;
      }
    } else if (event === EVENT_STANDALONE_CLEARED) {
      this.embedDismissed = false;
      if (sessionKey.length > 0) {
        this.lastClearedSessionKey = sessionKey;
      }
      // 一次会话闭环后清空，确保下一次嵌入重新生成新 sessionId。
      this.embedSessionId = '';
      if (publishTs > 0) {
        this.lastAppliedTs = publishTs;
      }
    }
  }

  private readNumber(raw: Object | undefined): number {
    if (raw == undefined) {
      return 0;
    }
    const num = Number(raw);
    return Number.isFinite(num) ? num : 0;
  }

  buildParams(): Record<string, Object> {
    this.ensureEmbedSessionId();
    const params: Record<string, Object> = {
      'test_flag': 'embed_test',
      'from': 'EmbedGrabTest',
      'isFullScreen': true
    };
    params[EMBED_ORIGIN_KEY] = 'host';
    params[EMBED_SESSION_ID_KEY] = this.embedSessionId;
    if (this.targetAbility.length > 0) {
      params['ability.params.targetAbilityName'] = this.targetAbility;
      params['abilityName'] = this.targetAbility;
    }
    return params;
  }

  private ensureEmbedSessionId(): void {
    if (this.embedSessionId.length > 0) {
      return;
    }
    this.embedSessionId = 'sess_' + Date.now().toString(36) + '_' + Math.floor(Math.random() * 100000).toString(36);
    this.log('embedSessionId=' + this.embedSessionId);
  }

  jumpOutStart(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const params: Record<string, Object> = {
        'test_flag': 'embed_test',
        'from': 'EmbedGrabTest_jumpout'
      };
      const abilityName = this.targetAbility.length > 0 ? this.targetAbility : 'EntryAbility';
      ctx.startAbility({
        bundleName: GRAB_BUNDLE,
        abilityName: abilityName,
        parameters: params
      }).then(() => {
        this.log('startAbility succeeded target=' + abilityName);
      }).catch((e: BusinessError) => {
        this.log(`startAbility failed code=${e.code} msg=${e.message}`);
      });
    } catch (e) {
      this.log('startAbility exception: ' + (e as BusinessError).message);
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('Grab 嵌入式拉起测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)

        Text('appId: ' + GRAB_APP_ID).fontSize(12).fontColor(Color.Gray)
        Text('Ability: ' + (this.targetAbility.length > 0 ? this.targetAbility : '默认(EntryAbility)'))
          .fontSize(12).fontColor(Color.Gray)

        Row({ space: 8 }) {
          Button('指定 EntryAbility')
            .fontSize(12)
            .onClick(() => {
              this.targetAbility = 'EntryAbility';
              this.log('target=EntryAbility');
            })
          Button('不指定(默认)')
            .fontSize(12)
            .onClick(() => {
              this.targetAbility = '';
              this.log('target=default');
            })
        }

        Divider()

        Text('全屏嵌入拉起').fontWeight(FontWeight.Medium)

        Column() {
          if (this.embedDismissed) {
            // 独立 Grab 已激活，嵌入面板已被协调关闭
            Text('Grab 已在独立应用中运行，请切换到 Grab 应用查看')
              .fontSize(13)
              .fontColor('#666')
              .padding(12)
              .backgroundColor('#F5F5F5')
              .borderRadius(6)
              .width('100%')
          } else {
            FullScreenLaunchComponent({
              content: this.EmbedEntryButton,
              appId: GRAB_APP_ID,
              options: {
                parameters: this.buildParams()
              }
            })
              .width('100%')
              .height(64)
              .backgroundColor('#FFFFFF')
          }
        }

        Divider()

        Text('跳出式拉起（对照）').fontWeight(FontWeight.Medium)
        Button('跳出式拉起 Grab')
          .onClick(() => this.jumpOutStart())

        Divider()

        Text('日志').fontWeight(FontWeight.Medium)
        Button('清除日志')
          .fontSize(12)
          .backgroundColor('#EEEEEE')
          .fontColor('#333333')
          .onClick(() => {
            this.logOutput = '';
          })
        Text(this.logOutput)
          .fontSize(11)
          .fontColor(Color.Gray)
          .maxLines(50)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F8F8')
  }

  @Builder
  EmbedEntryButton() {
    Row({ space: 12 }) {
      Column() {
        Text('G').fontSize(20).fontColor(Color.White).fontWeight(FontWeight.Bold)
      }
      .width(36).height(36).backgroundColor('#FF6600').borderRadius(18)
      .justifyContent(FlexAlign.Center)

      Column({ space: 2 }) {
        Text('点击嵌入打开 Grab').fontSize(14).fontColor(Color.White).fontWeight(FontWeight.Medium)
        Text('FullScreen 全屏嵌入').fontSize(10).fontColor('#CCFFFFFF')
      }.alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor('#007DFF').borderRadius(8)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }
}
