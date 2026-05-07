import { FullScreenLaunchComponent } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'EmbedGrabTestPage';
const DOMAIN = 0xA002;
const GRAB_APP_ID = '5765880207856208787';
const GRAB_BUNDLE = 'com.atomicservice.5765880207856208787';

@Entry
@ComponentV2
struct EmbedGrabTestPage {
  @Local targetAbility: string = '';
  @Local logOutput: string = '';

  log(msg: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', msg);
    this.logOutput = `[${new Date().toLocaleTimeString()}] ${msg}\n` + this.logOutput;
  }

  aboutToAppear(): void {
    this.log('page ready');
  }

  onPageShow(): void {
    this.log('onPageShow');
  }

  onPageHide(): void {
    this.log('onPageHide');
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
