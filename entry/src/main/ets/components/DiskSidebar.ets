import { DiskListItem } from '../model/ViewModels';
import { Layout } from '../service/Responsive';
import { accentBgColor, accentColor } from '../service/Theme';

const NAV_ROW_HEIGHT: number = 40;
const HOVER_HOME: number = 0;
const HOVER_DISKS: number = 1;
const HOVER_ABOUT: number = 2;

@Component
export struct DiskSidebar {
  @Prop items: DiskListItem[];
  @Prop selectedNode: string;
  @Prop homeSelected: boolean;
  @Prop disksSelected: boolean;
  @Prop scanning: boolean;
  @Prop lastScan: string;
  @Prop warningCount: number;
  @Prop accentName: string = 'blue';
  @State hovered: number = -1;
  @State disksExpanded: boolean = true;
  onSelect: (node: string) => void = () => {
  };
  onOpenHome: () => void = () => {
  };
  onOpenAbout: () => void = () => {
  };

  @Styles
  pressedRow() {
    .backgroundColor($r('app.color.chip_bg'))
  }

  private healthColor(health: number): Resource {
    if (health === 1) {
      return $r('app.color.good');
    }
    if (health === 2) {
      return $r('app.color.caution');
    }
    if (health === 3) {
      return $r('app.color.bad');
    }
    return $r('app.color.unknown');
  }

  private listHeight(): number {
    const rows: number = this.items.length;
    if (rows === 0) {
      return 0;
    }
    return Math.min(280, rows * 54 + (rows - 1) * 6 + 6);
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.startIcon'))
          .width(40)
          .height(40)
          .borderRadius(10)
        Column({ space: 2 }) {
          Text('DiskInfo')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.app_tagline'))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 14 })

      Column() {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.house'))
            .fontSize(22)
            .fontColor([this.homeSelected ? accentColor(this.accentName) : $r('app.color.text_primary')])
          Text($r('app.string.home'))
            .fontSize(15)
            .fontWeight(this.homeSelected ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.homeSelected ? accentColor(this.accentName) : $r('app.color.text_primary'))
            .maxLines(1)
        }
        .width('100%')
        .height(NAV_ROW_HEIGHT)
        .padding({ left: 14, right: 14 })
        .borderRadius(Layout.controlRadius())
        .backgroundColor(this.homeSelected ? accentBgColor(this.accentName) :
          (this.hovered === HOVER_HOME ? $r('app.color.chip_bg') : Color.Transparent))
        .stateStyles({ pressed: this.pressedRow })
        .focusable(true)
        .accessibilityGroup(true)
        .accessibilityText($r('app.string.home'))
        .onHover((isHover: boolean) => {
          if (isHover) {
            this.hovered = HOVER_HOME;
          } else if (this.hovered === HOVER_HOME) {
            this.hovered = -1;
          }
        })
        .onClick(() => {
          this.onOpenHome();
        })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 4 })

      Column() {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.externaldrive'))
            .fontSize(22)
            .fontColor([this.disksSelected ? accentColor(this.accentName) : $r('app.color.text_primary')])
          Text($r('app.string.disks'))
            .fontSize(15)
            .fontWeight(this.disksSelected ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.disksSelected ? accentColor(this.accentName) : $r('app.color.text_primary'))
            .maxLines(1)
            .layoutWeight(1)
          if (this.scanning) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color($r('app.color.text_tertiary'))
          }
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(16)
            .fontColor([$r('app.color.text_tertiary')])
            .rotate({ angle: this.disksExpanded ? 0 : -90 })
            .animation({ duration: 180, curve: Curve.EaseInOut })
        }
        .width('100%')
        .height(NAV_ROW_HEIGHT)
        .padding({ left: 14, right: 14 })
        .borderRadius(Layout.controlRadius())
        .backgroundColor(this.disksSelected ? accentBgColor(this.accentName) :
          (this.hovered === HOVER_DISKS ? $r('app.color.chip_bg') : Color.Transparent))
        .stateStyles({ pressed: this.pressedRow })
        .focusable(true)
        .accessibilityGroup(true)
        .accessibilityText($r('app.string.disks'))
        .onHover((isHover: boolean) => {
          if (isHover) {
            this.hovered = HOVER_DISKS;
          } else if (this.hovered === HOVER_DISKS) {
            this.hovered = -1;
          }
        })
        .onClick(() => {
          this.disksExpanded = !this.disksExpanded;
        })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 4 })

      if (this.disksExpanded) {
        if (this.items.length > 0) {
          List({ space: 6 }) {
            ForEach(this.items, (item: DiskListItem) => {
              ListItem() {
                Row({ space: 10 }) {
                  Circle()
                    .width(9)
                    .height(9)
                    .fill(this.healthColor(item.health))
                  Column({ space: 3 }) {
                    Text(item.title)
                      .fontSize(13)
                      .fontWeight(this.selectedNode === item.node ? FontWeight.Medium : FontWeight.Normal)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.subtitle)
                      .fontSize(11)
                      .fontColor($r('app.color.text_tertiary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 24, right: 10, top: 9, bottom: 9 })
                .borderRadius(10)
                .backgroundColor(this.selectedNode === item.node ? accentBgColor(this.accentName) : Color.Transparent)
                .onClick(() => {
                  this.onSelect(item.node);
                })
              }
            }, (item: DiskListItem) => item.node + item.title + item.subtitle)
          }
          .height(this.listHeight())
          .width('100%')
          .padding({ left: 10, right: 10, bottom: 6 })
          .scrollBar(BarState.Off)
        } else {
          Text($r('app.string.no_disk'))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .padding({ left: 56, right: 16, top: 4, bottom: 10 })
            .width('100%')
        }
      }

      Blank()

      Column({ space: 2 }) {
        if (this.warningCount > 0) {
          Row({ space: 4 }) {
            Text($r('app.string.warnings'))
              .fontSize(10)
              .fontColor($r('app.color.caution'))
            Text(this.warningCount.toString())
              .fontSize(10)
              .fontColor($r('app.color.caution'))
          }
        }
        if (this.lastScan.length > 0) {
          Row({ space: 4 }) {
            Text($r('app.string.last_scan'))
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
            Text(this.lastScan)
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 6 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(22)
            .fontColor([$r('app.color.text_primary')])
          Text($r('app.string.about'))
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
        }
        .width('100%')
        .height(NAV_ROW_HEIGHT)
        .padding({ left: 14, right: 14 })
        .borderRadius(Layout.controlRadius())
        .backgroundColor(this.hovered === HOVER_ABOUT ? $r('app.color.chip_bg') : Color.Transparent)
        .stateStyles({ pressed: this.pressedRow })
        .focusable(true)
        .accessibilityGroup(true)
        .accessibilityText($r('app.string.about'))
        .onHover((isHover: boolean) => {
          if (isHover) {
            this.hovered = HOVER_ABOUT;
          } else if (this.hovered === HOVER_ABOUT) {
            this.hovered = -1;
          }
        })
        .onClick(() => {
          this.onOpenAbout();
        })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.sidebar_bg'))
  }
}
