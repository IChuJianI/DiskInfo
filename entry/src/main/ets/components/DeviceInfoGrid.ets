import { InfoEntry } from '../model/ViewModels';

@Component
export struct DeviceInfoGrid {
  @Prop entries: InfoEntry[];

  @Builder
  cell(entry: InfoEntry) {
    Column({ space: 4 }) {
      Text(entry.label)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .maxLines(1)
      Text(entry.value.length > 0 ? entry.value : '---')
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  build() {
    Column({ space: 14 }) {
      Text($r('app.string.info_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Column({ space: 14 }) {
        ForEach(this.entries, (entry: InfoEntry, index: number) => {
          if (index % 2 === 0) {
            Row({ space: 18 }) {
              this.cell(entry)
              if (index + 1 < this.entries.length) {
                this.cell(this.entries[index + 1])
              } else {
                Blank()
                  .layoutWeight(1)
              }
            }
            .width('100%')
          }
        }, (entry: InfoEntry, index: number) =>
          entry.label + index.toString() + ':' + entry.value)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }
}
