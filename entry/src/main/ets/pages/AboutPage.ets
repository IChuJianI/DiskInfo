import { bundleManager } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { AppSettings } from '../service/SettingsService';
import { accentColor } from '../service/Theme';

const PAGE_ROOT: number = 0;
const PAGE_LICENSE: number = 1;
const SECTION_PROJECTS: number = 0;
const SECTION_MIT: number = 1;
const SECTION_THIRD_PARTY: number = 2;
const LICENSE_CHUNK_CHARS: number = 1800;
const UPSTREAM_LICENSE_FILE: string = 'CrystalDiskInfo_LICENSE.txt';
const SUPPLEMENT_FILE: string = 'DiskInfo_THIRD_PARTY_NOTICES.md';
const PROJECT_LICENSE_FILE: string = 'DiskInfo_LICENSE.txt';
const VIEWER_UPSTREAM: number = 0;
const VIEWER_SUPPLEMENT: number = 1;
const VIEWER_PROJECT: number = 2;
const EMAIL: string = '3093376617@qq.com';
const WEBSITE: string = 'www.52wfun.com';
const APP_NAME: string = 'DiskInfo';
const APP_COPYRIGHT: string = 'Copyright (c) 2026 李晨';
const APP_REPO_URL: string = 'https://github.com/IChuJianI/DiskInfo';
const CDI_NAME: string = 'CrystalDiskInfo';
const CDI_COPYRIGHT: string = 'Copyright (c) 2008-2023 hiyohiyo';
const CDI_URL: string = 'https://github.com/hiyohiyo/CrystalDiskInfo';

const MIT_LICENSE_TEXT: string = `MIT License

Copyright (c) 2008-2023 hiyohiyo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
`;

class LicenseTextSource implements IDataSource {
  private items: string[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): string {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  setItems(items: string[]): void {
    this.items = items;
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}

function splitLicenseText(text: string): string[] {
  const chunks: string[] = [];
  const lines = text.split('\n');
  let start = 0;
  let length = 0;
  for (let i = 0; i < lines.length; i++) {
    length += lines[i].length + 1;
    if (length >= LICENSE_CHUNK_CHARS) {
      chunks.push(lines.slice(start, i + 1).join('\n'));
      start = i + 1;
      length = 0;
    }
  }
  if (start < lines.length) {
    chunks.push(lines.slice(start).join('\n'));
  }
  return chunks;
}

@Component
export struct AboutPage {
  @StorageLink('diskinfoSettings') settings: AppSettings = new AppSettings();
  @State page: number = PAGE_ROOT;
  @State expanded: number = -1;
  @State viewerOpen: boolean = false;
  @State viewerKind: number = VIEWER_UPSTREAM;
  private version: string = '';
  private bundleName: string = 'com.52wfun.diskinfo';
  private licenseSource: LicenseTextSource = new LicenseTextSource();
  private loadedKind: number = -1;

  aboutToAppear(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.version = info.versionName;
      this.bundleName = info.name;
    } catch (error) {
      this.version = '1.0';
    }
  }

  private async copyText(text: string, message: Resource): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (error) {
    }
  }

  private openLicense(kind: number): void {
    try {
      if (this.loadedKind !== kind) {
        const context = this.getUIContext().getHostContext();
        if (!context) {
          throw new Error('host context unavailable');
        }
        const file = kind === VIEWER_SUPPLEMENT ? SUPPLEMENT_FILE :
          (kind === VIEWER_PROJECT ? PROJECT_LICENSE_FILE : UPSTREAM_LICENSE_FILE);
        const bytes = context.resourceManager.getRawFileContentSync(file);
        const decoder = util.TextDecoder.create('utf-8');
        this.licenseSource.setItems(splitLicenseText(decoder.decodeToString(bytes)));
        this.loadedKind = kind;
      }
      this.viewerKind = kind;
      this.viewerOpen = true;
    } catch (error) {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: $r('app.string.toast_license_read_failed'),
          duration: 2000
        });
      } catch (toastError) {
      }
    }
  }

  @Builder
  brandCard() {
    Row({ space: 14 }) {
      Image($r('app.media.startIcon'))
        .width(48)
        .height(48)
        .borderRadius(14)
        .clip(true)
      Column({ space: 3 }) {
        Text('DiskInfo')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
        Text($r('app.string.app_tagline'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(96)
    .padding({ left: 16, right: 16 })
    .borderRadius(15)
    .backgroundColor($r('app.color.card_bg'))
    .accessibilityGroup(true)
  }

  @Builder
  infoCard(label: Resource, value: ResourceStr) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 12, top: 10, bottom: 10 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .borderRadius(15)
    .backgroundColor($r('app.color.card_bg'))
    .accessibilityGroup(true)
  }

  @Builder
  copyCard(label: Resource, value: string, message: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 2 }) {
        Text(label)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(value)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(accentColor(this.settings.accentColor))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(15)
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityGroup(true)
    .onClick((): void => {
      this.copyText(value, message);
    })
  }

  @Builder
  licensesCard() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        Text($r('app.string.about_license'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.text_secondary')])
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(15)
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityGroup(true)
    .onClick((): void => {
      this.page = PAGE_LICENSE;
    })
  }

  @Builder
  aboutContent() {
    Row() {
      List({ space: 12 }) {
        ListItem() {
          this.brandCard()
        }

        ListItem() {
          Row({ space: 8 }) {
            this.infoCard($r('app.string.about_version'), this.version)
            this.infoCard($r('app.string.about_developer'), $r('app.string.about_developer_name'))
          }
          .width('100%')
        }

        ListItem() {
          Row({ space: 8 }) {
            this.infoCard($r('app.string.about_bundle'), this.bundleName)
            this.copyCard($r('app.string.about_website'), WEBSITE,
              $r('app.string.about_website_copied'))
          }
          .width('100%')
        }

        ListItem() {
          Row({ space: 8 }) {
            this.copyCard($r('app.string.about_email'), EMAIL,
              $r('app.string.about_email_copied'))
            this.licensesCard()
          }
          .width('100%')
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: 800 })
      .height('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  NavBack(label: Resource, hint: Resource, action: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 2 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(16)
          .fontColor([accentColor(this.settings.accentColor)])
        Text(label)
          .fontSize(14)
          .fontColor(accentColor(this.settings.accentColor))
      }
    }
    .height(40)
    .padding({ left: 8, right: 12 })
    .backgroundColor(Color.Transparent)
    .borderRadius(8)
    .hoverEffect(HoverEffect.Highlight)
    .accessibilityText(hint)
    .onClick(() => action())
  }

  @Builder
  DocButton(label: Resource, action: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 6 }) {
        Text(label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(accentColor(this.settings.accentColor))
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([accentColor(this.settings.accentColor)])
      }
    }
    .constraintSize({ minHeight: 40 })
    .padding({ left: 0, right: 0 })
    .backgroundColor(Color.Transparent)
    .hoverEffect(HoverEffect.Highlight)
    .onClick(() => action())
  }

  @Builder
  SectionHeader(index: number, title: ResourceStr, subtitle: ResourceStr) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(subtitle)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(16)
          .fontColor([$r('app.color.text_secondary')])
          .rotate({ angle: this.expanded === index ? 180 : 0 })
          .accessibilityLevel('no')
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .hoverEffect(HoverEffect.Highlight)
    .onClick(() => {
      this.expanded = this.expanded === index ? -1 : index;
    })
  }

  @Builder
  ProjectInfo(name: string, copyright: string, url: string) {
    Column({ space: 2 }) {
      Text(name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(copyright)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text(url)
          .fontSize(12)
          .fontColor(accentColor(this.settings.accentColor))
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: 40 })
      .padding({ left: 0, right: 0 })
      .backgroundColor(Color.Transparent)
      .hoverEffect(HoverEffect.Highlight)
      .accessibilityText(url)
      .onClick(() => {
        this.copyText(url, $r('app.string.toast_link_copied'));
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TextBlock(label: Resource, body: ResourceStr) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(body)
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.text_secondary'))
        .copyOption(CopyOptions.LocalDevice)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProjectsSection() {
    Column({ space: 10 }) {
      Text($r('app.string.licenses_this_project'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      this.ProjectInfo(APP_NAME, APP_COPYRIGHT, APP_REPO_URL)
      this.DocButton($r('app.string.licenses_view_project'), () => this.openLicense(VIEWER_PROJECT))
      Text($r('app.string.licenses_upstream_project'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ top: 4 })
      this.ProjectInfo(CDI_NAME, CDI_COPYRIGHT, CDI_URL)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MitSection() {
    Column({ space: 10 }) {
      this.TextBlock($r('app.string.licenses_components'), $r('app.string.crystaldiskinfo_components'))
      this.TextBlock($r('app.string.licenses_copyright'), CDI_COPYRIGHT)
      this.TextBlock($r('app.string.licenses_full_text'), MIT_LICENSE_TEXT)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ThirdPartySection() {
    Column({ space: 10 }) {
      this.TextBlock($r('app.string.licenses_note_label'), $r('app.string.licenses_note_body'))
      this.DocButton($r('app.string.licenses_view_upstream'), () => this.openLicense(VIEWER_UPSTREAM))
      this.DocButton($r('app.string.licenses_view_supplement'), () => this.openLicense(VIEWER_SUPPLEMENT))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  licenseContent() {
    Scroll() {
      Row() {
        Column() {
          this.SectionHeader(SECTION_PROJECTS,
            $r('app.string.licenses_section_projects'), 'DiskInfo · CrystalDiskInfo')
          if (this.expanded === SECTION_PROJECTS) {
            Divider()
              .color($r('app.color.divider'))
            this.ProjectsSection()
          }

          Divider()
            .color($r('app.color.divider'))
          this.SectionHeader(SECTION_MIT, 'MIT License', $r('app.string.licenses_section_mit_sub'))
          if (this.expanded === SECTION_MIT) {
            Divider()
              .color($r('app.color.divider'))
            this.MitSection()
          }

          Divider()
            .color($r('app.color.divider'))
          this.SectionHeader(SECTION_THIRD_PARTY,
            $r('app.string.licenses_section_third'), $r('app.string.licenses_section_third_sub'))
          if (this.expanded === SECTION_THIRD_PARTY) {
            Divider()
              .color($r('app.color.divider'))
            this.ThirdPartySection()
          }
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(15)
        .clip(true)
      }
      .width('100%')
      .constraintSize({ maxWidth: 800 })
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  viewerContent() {
    Row() {
      Column() {
        Row() {
          this.NavBack($r('app.string.licenses_list_title'), $r('app.string.a11y_licenses_back'), () => {
            this.viewerOpen = false;
          })
        }
        .width('100%')
        .padding({ left: 8, right: 16, top: 8 })

        Column({ space: 2 }) {
          Text(this.viewerKind === VIEWER_SUPPLEMENT ?
            $r('app.string.licenses_supplement_title') :
            (this.viewerKind === VIEWER_PROJECT ? 'DiskInfo License' : 'CrystalDiskInfo License'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text(this.viewerKind === VIEWER_SUPPLEMENT ?
            $r('app.string.licenses_supplement_sub') :
            (this.viewerKind === VIEWER_PROJECT ?
              $r('app.string.licenses_project_sub') : $r('app.string.licenses_upstream_sub')))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })

        List() {
          LazyForEach(this.licenseSource, (chunk: string, index: number) => {
            ListItem() {
              Text(chunk)
                .fontSize(12)
                .lineHeight(18)
                .fontColor($r('app.color.text_secondary'))
                .copyOption(CopyOptions.LocalDevice)
                .width('100%')
                .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            }
          }, (chunk: string, index: number) => `lic:${index}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .cachedCount(4)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: 800 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.page_bg'))
  }

  build() {
    NavDestination() {
      if (this.page === PAGE_LICENSE) {
        if (this.viewerOpen) {
          this.viewerContent()
        } else {
          this.licenseContent()
        }
      } else {
        this.aboutContent()
      }
    }
    .title(this.page === PAGE_LICENSE ? $r('app.string.about_license') : $r('app.string.about'), {
      barStyle: BarStyle.STANDARD,
      backgroundColor: $r('app.color.sidebar_bg')
    })
    .onBackPressed(() => {
      if (this.viewerOpen) {
        this.viewerOpen = false;
        return true;
      }
      if (this.page === PAGE_LICENSE) {
        this.page = PAGE_ROOT;
        return true;
      }
      return false;
    })
    .backgroundColor($r('app.color.page_bg'))
  }
}
