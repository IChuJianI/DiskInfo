@Component
export struct OverviewCards {
  @Prop health: number;
  @Prop healthText: string;
  @Prop temperatureText: string;
  @Prop temperatureAlarm: boolean;
  @Prop lifeText: string;
  @Prop lifeEstimated: boolean;
  @Prop powerOnHoursText: string;
  @Prop powerOnCountText: string;

  private healthColor(): Resource {
    if (this.health === 1) {
      return $r('app.color.good');
    }
    if (this.health === 2) {
      return $r('app.color.caution');
    }
    if (this.health === 3) {
      return $r('app.color.bad');
    }
    return $r('app.color.unknown');
  }

  @Builder
  cardLabel(label: Resource) {
    Text(label)
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
  }

  build() {
    GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
      GridCol({ span: { xs: 6, sm: 6, md: 3, lg: 3 } }) {
        Column({ space: 6 }) {
          this.cardLabel($r('app.string.health'))
          Row({ space: 8 }) {
            Circle()
              .width(12)
              .height(12)
              .fill(this.healthColor())
            Text(this.healthText)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.healthColor())
          }
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(96)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(16)
      }

      GridCol({ span: { xs: 6, sm: 6, md: 3, lg: 3 } }) {
        Column({ space: 6 }) {
          this.cardLabel($r('app.string.temperature'))
          Text(this.temperatureText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.temperatureAlarm ? $r('app.color.bad') : $r('app.color.text_primary'))
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(96)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(16)
      }

      GridCol({ span: { xs: 6, sm: 6, md: 3, lg: 3 } }) {
        Column({ space: 6 }) {
          this.cardLabel($r('app.string.life'))
          Text(this.lifeText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          if (this.lifeEstimated) {
            Text($r('app.string.life_estimated'))
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(96)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(16)
      }

      GridCol({ span: { xs: 6, sm: 6, md: 3, lg: 3 } }) {
        Column({ space: 6 }) {
          this.cardLabel($r('app.string.power_on_hours'))
          Text(this.powerOnHoursText)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.powerOnCountText)
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .maxLines(1)
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height(96)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(16)
      }
    }
    .width('100%')
  }
}
