import { SmartRow } from '../model/ViewModels';

@Component
export struct SmartTable {
  @Prop rows: SmartRow[];

  @Builder
  headerCell(label: Resource, width: number) {
    Text(label)
      .fontSize(11)
      .fontColor($r('app.color.text_tertiary'))
      .width(width)
      .textAlign(TextAlign.End)
  }

  build() {
    Column() {
      Text($r('app.string.smart_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ bottom: 10 })

      Scroll() {
        Column() {
          Row() {
            Text($r('app.string.col_id'))
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
              .width(44)
            Text($r('app.string.col_name'))
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
              .layoutWeight(3)
            this.headerCell($r('app.string.col_current'), 68)
            this.headerCell($r('app.string.col_worst'), 68)
            this.headerCell($r('app.string.col_threshold'), 68)
            this.headerCell($r('app.string.col_raw'), 132)
          }
          .width('100%')
          .height(28)

          Divider()
            .color($r('app.color.divider'))

          ForEach(this.rows, (row: SmartRow) => {
            Row() {
              Text(row.id)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width(44)
              Text(row.name)
                .fontSize(12)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(3)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(row.current)
                .fontSize(12)
                .fontColor(row.warn ? $r('app.color.bad') : $r('app.color.text_primary'))
                .width(68)
                .textAlign(TextAlign.End)
              Text(row.worst)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width(68)
                .textAlign(TextAlign.End)
              Text(row.threshold)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width(68)
                .textAlign(TextAlign.End)
              Text(row.raw)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width(132)
                .textAlign(TextAlign.End)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(32)

            Divider()
              .color($r('app.color.divider'))
          }, (row: SmartRow) => row.id + row.name + row.current + '/' +
            row.worst + '/' + row.threshold + '/' + row.raw + '/' + row.warn.toString())
        }
        .width('100%')
        .constraintSize({ minWidth: 500 })
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }
}
