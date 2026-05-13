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

@Entry
@ComponentV2
struct EmbedGrabTestPage {
  @Local targetAbility: string = '';
  @Local logOutput: string = '';
  /** 监听独立 Grab 发来的"关闭嵌入面板"信号——为 true 时不渲染 FullScreenLaunchComponent */
  @Local embedDismissed: boolean = false;
  private subscriber?: commonEventManager.CommonEventSubscriber;

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
    if (event === EVENT_STANDALONE_ACTIVE) {
      this.embedDismissed = true;
    } else if (event === EVENT_STANDALONE_CLEARED) {
      this.embedDismissed = false;
    }
  }

  buildParams(): Record<string, Object> {
    const params: Record<string, Object> = {
      'test_flag': 'embed_test',
      'from': 'EmbedGrabTest',
      'isFullScreen': true
    };
    if (this.targetAbility.length > 0) {
      params['ability.params.targetAbilityName'] = this.targetAbility;
      params['abilityName'] = this.targetAbility;
    }
    return params;
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
          Button('指定 EmbedTestAbility')
            .fontSize(12)
            .onClick(() => {
              this.targetAbility = 'EmbedTestAbility';
              this.log('target=EmbedTestAbility');
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
