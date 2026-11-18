import { Breakpoint, Layout } from '../service/Responsive';

@Component
export struct DiagnosticsView {
  @StorageLink('diskinfoMessages') messages: string[] = [];
  @StorageLink('diskinfoBreakpoint') breakpoint: number = Breakpoint.Lg;

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 8 }) {
          Text($r('app.string.diag_channels'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          if (this.messages.length === 0) {
            Text('---')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
          }
          ForEach(this.messages, (message: string, index: number) => {
            Text(message)
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }, (message: string, index: number) => index.toString() + message)
        }
        .width('100%')
        .padding(18)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(16)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        left: Layout.pagePadding(this.breakpoint),
        right: Layout.pagePadding(this.breakpoint),
        top: 16,
        bottom: 32
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor($r('app.color.page_bg'))
  }
}

@Component
export struct DiagnosticsPage {
  build() {
    NavDestination() {
      DiagnosticsView()
    }
    .title($r('app.string.diag_title'), {
      barStyle: BarStyle.STANDARD,
      backgroundColor: $r('app.color.sidebar_bg')
    })
    .backgroundColor($r('app.color.page_bg'))
  }
}
