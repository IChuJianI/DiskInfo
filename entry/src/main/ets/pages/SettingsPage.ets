import { common } from '@kit.AbilityKit';
import i18n from '@ohos.i18n';
import { AppSettings, SettingsService } from '../service/SettingsService';
import { Breakpoint, isPcDevice, Layout } from '../service/Responsive';
import {
  accentColor,
  ACCENT_BLUE,
  ACCENT_PURPLE,
  ACCENT_RED,
  ACCENT_TEAL,
  preferredLanguage,
  setAppThemeMode
} from '../service/Theme';

const PAGE_ROOT: number = 0;
const PAGE_DETECTION: number = 1;
const PAGE_LANGUAGE: number = 2;
const PAGE_APPEARANCE: number = 3;

@Component
export struct SettingsView {
  @StorageLink('diskinfoSettings') settings: AppSettings = new AppSettings();
  @StorageLink('diskinfoBreakpoint') breakpoint: number = Breakpoint.Lg;
  @Prop page: number = PAGE_ROOT;
  @State draft: AppSettings = new AppSettings();
  onOpenAbout: () => void = () => {
  };
  onOpenPage: (page: number) => void = () => {
  };
  private service: SettingsService = new SettingsService();
  private context: common.Context | null = null;
  private refreshValues: number[] = [5, 10, 30, 60];
  private refreshOptions: SelectOption[] = [
    { value: '5 s' }, { value: '10 s' }, { value: '30 s' }, { value: '60 s' }
  ];
  private alarmValues: number[] = [45, 50, 55, 60, 65, 70];
  private alarmOptions: SelectOption[] = [
    { value: '45 °C' }, { value: '50 °C' }, { value: '55 °C' },
    { value: '60 °C' }, { value: '65 °C' }, { value: '70 °C' }
  ];
  private thresholdValues: number[] = [0, 1, 2, 5, 10, 20, 50];
  private thresholdOptions: SelectOption[] = [
    { value: '0' }, { value: '1' }, { value: '2' }, { value: '5' },
    { value: '10' }, { value: '20' }, { value: '50' }
  ];
  private ffValues: number[] = [5, 10, 15, 20, 30];
  private ffOptions: SelectOption[] = [
    { value: '5' }, { value: '10' }, { value: '15' }, { value: '20' }, { value: '30' }
  ];

  aboutToAppear(): void {
    const host = this.getUIContext().getHostContext();
    if (host !== undefined) {
      this.context = host as common.Context;
      this.service.open(this.context);
    }
    this.draft = this.copy(this.settings);
  }

  private stringById(id: number): string {
    if (this.context === null) {
      return '';
    }
    try {
      return this.context.resourceManager.getStringSync(id);
    } catch (error) {
      return '';
    }
  }

  private copy(source: AppSettings): AppSettings {
    const target = new AppSettings();
    target.refreshSeconds = source.refreshSeconds;
    target.useCelsius = source.useCelsius;
    target.alarmTemperature = source.alarmTemperature;
    target.threshold05 = source.threshold05;
    target.thresholdC5 = source.thresholdC5;
    target.thresholdC6 = source.thresholdC6;
    target.thresholdFF = source.thresholdFF;
    target.rawHexadecimal = source.rawHexadecimal;
    target.hideSerial = source.hideSerial;
    target.language = source.language;
    target.themeMode = source.themeMode;
    target.accentColor = source.accentColor;
    return target;
  }

  private selectWidth(base: number): number {
    return this.breakpoint === Breakpoint.Sm ? 128 : base;
  }

  private indexOf(values: number[], value: number): number {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === value) {
        return i;
      }
    }
    return 0;
  }

  private languageLabel(): string {
    if (this.draft.language === 'zh') {
      return this.stringById($r('app.string.language_zh').id);
    }
    if (this.draft.language === 'zh-Hant') {
      return this.stringById($r('app.string.language_zh_hant').id);
    }
    if (this.draft.language === 'en') {
      return this.stringById($r('app.string.language_en').id);
    }
    if (this.draft.language === 'ja') {
      return this.stringById($r('app.string.language_ja').id);
    }
    if (this.draft.language === 'ko') {
      return this.stringById($r('app.string.language_ko').id);
    }
    if (this.draft.language === 'ru') {
      return this.stringById($r('app.string.language_ru').id);
    }
    return this.stringById($r('app.string.language_auto').id);
  }

  private accentLabel(): string {
    if (this.draft.accentColor === 'red') {
      return this.stringById($r('app.string.accent_red').id);
    }
    if (this.draft.accentColor === 'purple') {
      return this.stringById($r('app.string.accent_purple').id);
    }
    if (this.draft.accentColor === 'teal') {
      return this.stringById($r('app.string.accent_teal').id);
    }
    return this.stringById($r('app.string.accent_blue').id);
  }

  private themeLabel(): string {
    if (this.draft.themeMode === 'light') {
      return this.stringById($r('app.string.settings_light').id);
    }
    if (this.draft.themeMode === 'dark') {
      return this.stringById($r('app.string.settings_dark').id);
    }
    return this.stringById($r('app.string.settings_theme_auto').id);
  }

  private appearanceSummary(): string {
    return this.themeLabel() + ' · ' + this.accentLabel();
  }

  private persist(): void {
    this.service.save(this.draft);
    this.settings = this.copy(this.draft);
  }

  private applyLanguage(language: string): void {
    const target = preferredLanguage(language);
    try {
      if (i18n.System.getAppPreferredLanguage() === target) {
        return;
      }
    } catch (error) {
    }
    setTimeout(() => {
      try {
        i18n.System.setAppPreferredLanguage(target);
      } catch (error) {
      }
    }, 0);
  }

  @Styles
  pressedCard() {
    .backgroundColor($r('app.color.chip_bg'))
  }

  @Builder
  groupLabel(label: Resource) {
    Text(label)
      .fontSize(13)
      .fontColor($r('app.color.text_tertiary'))
      .width('100%')
      .padding({ left: 16, top: 22, bottom: 10 })
  }

  @Builder
  cellLabel(label: Resource) {
    Text(label)
      .fontSize(15)
      .fontColor($r('app.color.text_primary'))
      .layoutWeight(1)
  }

  @Builder
  cellDivider() {
    Divider()
      .strokeWidth(1)
      .color($r('app.color.divider'))
      .margin({ left: 16, right: 16 })
  }

  @Builder
  languageRow(label: Resource, code: string) {
    Row() {
      this.cellLabel(label)
      if (this.draft.language === code) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(20)
          .fontColor([accentColor(this.draft.accentColor)])
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.draft.language = code;
      this.persist();
      this.applyLanguage(code);
    })
  }

  @Builder
  languageContent() {
    Column() {
      this.languageRow($r('app.string.language_auto'), 'auto')
      this.cellDivider()
      this.languageRow($r('app.string.language_zh'), 'zh')
      this.cellDivider()
      this.languageRow($r('app.string.language_zh_hant'), 'zh-Hant')
      this.cellDivider()
      this.languageRow($r('app.string.language_en'), 'en')
      this.cellDivider()
      this.languageRow($r('app.string.language_ja'), 'ja')
      this.cellDivider()
      this.languageRow($r('app.string.language_ko'), 'ko')
      this.cellDivider()
      this.languageRow($r('app.string.language_ru'), 'ru')
    }
    .width('100%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)

  }

  @Builder
  accentSwatch(name: string, color: string, label: Resource) {
    Column({ space: 6 }) {
      Stack() {
        Circle()
          .width(34)
          .height(34)
          .fill(color)
        if (this.draft.accentColor === name) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(18)
            .fontColor([Color.White])
        }
      }
      .width(34)
      .height(34)

      Text(label)
        .fontSize(11)
        .fontColor(this.draft.accentColor === name ? $r('app.color.text_primary') :
          $r('app.color.text_tertiary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .onClick(() => {
      this.draft.accentColor = name;
      this.persist();
    })
  }

  @Builder
  themeRow(label: Resource, code: string) {
    Row() {
      this.cellLabel(label)
      if (this.draft.themeMode === code) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(20)
          .fontColor([accentColor(this.draft.accentColor)])
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.draft.themeMode = code;
      this.persist();
      if (this.context !== null) {
        setAppThemeMode(this.context, code);
      }
    })
  }

  @Builder
  appearanceContent() {
    this.groupLabel($r('app.string.settings_theme_mode'))

    Column() {
      this.themeRow($r('app.string.settings_theme_auto'), 'auto')
      this.cellDivider()
      this.themeRow($r('app.string.settings_light'), 'light')
      this.cellDivider()
      this.themeRow($r('app.string.settings_dark'), 'dark')
    }
    .width('100%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)

    this.groupLabel($r('app.string.settings_accent'))

    Row() {
      this.accentSwatch('blue', ACCENT_BLUE, $r('app.string.accent_blue'))
      this.accentSwatch('red', ACCENT_RED, $r('app.string.accent_red'))
      this.accentSwatch('purple', ACCENT_PURPLE, $r('app.string.accent_purple'))
      this.accentSwatch('teal', ACCENT_TEAL, $r('app.string.accent_teal'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }

  @Builder
  navCard(title: Resource, subtitle: string, hasSubtitle: boolean, action: () => void) {
    Row() {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (hasSubtitle) {
          Text(subtitle)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('app.color.text_tertiary')])
    }
    .width('100%')
    .height(76)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .stateStyles({ pressed: this.pressedCard })
    .hoverEffect(HoverEffect.Highlight)
    .focusable(true)
    .accessibilityGroup(true)
    .accessibilityText(title)
    .margin({ bottom: 10 })
    .onClick(action)
  }

  @Builder
  rootContent() {
    this.groupLabel($r('app.string.settings_group_general'))

    this.navCard($r('app.string.settings_language'), this.languageLabel(), true, (): void => {
      this.onOpenPage(PAGE_LANGUAGE);
    })

    this.navCard($r('app.string.settings_appearance'), this.appearanceSummary(), true, (): void => {
      this.onOpenPage(PAGE_APPEARANCE);
    })

    this.groupLabel($r('app.string.settings_group_detection'))

    this.navCard($r('app.string.settings_core'), '', false, (): void => {
      this.onOpenPage(PAGE_DETECTION);
    })

    if (!isPcDevice() || this.breakpoint !== Breakpoint.Lg) {
      this.groupLabel($r('app.string.about'))

      this.navCard($r('app.string.about'), '', false, (): void => {
        this.onOpenAbout();
      })
    }
  }

  @Builder
  detectionContent() {
    this.groupLabel($r('app.string.settings_display'))

    Column() {
      Row() {
        this.cellLabel($r('app.string.settings_refresh'))
        Select(this.refreshOptions)
          .selected(this.indexOf(this.refreshValues, this.draft.refreshSeconds))
          .value(this.draft.refreshSeconds.toString() + ' s')
          .font({ size: 13 })
          .width(this.selectWidth(140))
          .onSelect((index: number) => {
            this.draft.refreshSeconds = this.refreshValues[index];
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.cellDivider()

      Row() {
        this.cellLabel($r('app.string.settings_unit'))
        Select([
          { value: this.stringById($r('app.string.settings_unit_c').id) },
          { value: this.stringById($r('app.string.settings_unit_f').id) }
        ])
          .selected(this.draft.useCelsius ? 0 : 1)
          .value(this.draft.useCelsius ? this.stringById($r('app.string.settings_unit_c').id) :
            this.stringById($r('app.string.settings_unit_f').id))
          .font({ size: 13 })
          .width(this.selectWidth(160))
          .onSelect((index: number) => {
            this.draft.useCelsius = index === 0;
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.cellDivider()

      Row() {
        this.cellLabel($r('app.string.settings_raw'))
        Select([
          { value: this.stringById($r('app.string.settings_raw_dec').id) },
          { value: this.stringById($r('app.string.settings_raw_hex').id) }
        ])
          .selected(this.draft.rawHexadecimal ? 1 : 0)
          .value(this.draft.rawHexadecimal ? this.stringById($r('app.string.settings_raw_hex').id) :
            this.stringById($r('app.string.settings_raw_dec').id))
          .font({ size: 13 })
          .width(this.selectWidth(160))
          .onSelect((index: number) => {
            this.draft.rawHexadecimal = index === 1;
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.cellDivider()

      Row() {
        this.cellLabel($r('app.string.settings_hide_serial'))
        Toggle({ type: ToggleType.Switch, isOn: this.draft.hideSerial })
          .selectedColor(accentColor(this.draft.accentColor))
          .onChange((isOn: boolean) => {
            this.draft.hideSerial = isOn;
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)

    this.groupLabel($r('app.string.settings_thresholds'))

    Column() {
      Row() {
        this.cellLabel($r('app.string.settings_alarm'))
        Select(this.alarmOptions)
          .selected(this.indexOf(this.alarmValues, this.draft.alarmTemperature))
          .value(this.draft.alarmTemperature.toString() + ' °C')
          .font({ size: 13 })
          .width(this.selectWidth(140))
          .onSelect((index: number) => {
            this.draft.alarmTemperature = this.alarmValues[index];
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.cellDivider()

      Row() {
        this.cellLabel($r('app.string.settings_threshold_05'))
        Select(this.thresholdOptions)
          .selected(this.indexOf(this.thresholdValues, this.draft.threshold05))
          .value(this.draft.threshold05.toString())
          .font({ size: 13 })
          .width(this.selectWidth(140))
          .onSelect((index: number) => {
            this.draft.threshold05 = this.thresholdValues[index];
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.cellDivider()

      Row() {
        this.cellLabel($r('app.string.settings_threshold_c5'))
        Select(this.thresholdOptions)
          .selected(this.indexOf(this.thresholdValues, this.draft.thresholdC5))
          .value(this.draft.thresholdC5.toString())
          .font({ size: 13 })
          .width(this.selectWidth(140))
          .onSelect((index: number) => {
            this.draft.thresholdC5 = this.thresholdValues[index];
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.cellDivider()

      Row() {
        this.cellLabel($r('app.string.settings_threshold_c6'))
        Select(this.thresholdOptions)
          .selected(this.indexOf(this.thresholdValues, this.draft.thresholdC6))
          .value(this.draft.thresholdC6.toString())
          .font({ size: 13 })
          .width(this.selectWidth(140))
          .onSelect((index: number) => {
            this.draft.thresholdC6 = this.thresholdValues[index];
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.cellDivider()

      Row() {
        this.cellLabel($r('app.string.settings_threshold_ff'))
        Select(this.ffOptions)
          .selected(this.indexOf(this.ffValues, this.draft.thresholdFF))
          .value(this.draft.thresholdFF.toString())
          .font({ size: 13 })
          .width(this.selectWidth(140))
          .onSelect((index: number) => {
            this.draft.thresholdFF = this.ffValues[index];
            this.persist();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)

  }

  build() {
    Scroll() {
      Column() {
        if (this.page === PAGE_DETECTION) {
          this.detectionContent()
        } else if (this.page === PAGE_LANGUAGE) {
          this.languageContent()
        } else if (this.page === PAGE_APPEARANCE) {
          this.appearanceContent()
        } else {
          this.rootContent()
        }
      }
      .width('100%')
      .padding({
        left: Layout.pagePadding(this.breakpoint),
        right: Layout.pagePadding(this.breakpoint),
        top: 4,
        bottom: 24
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor($r('app.color.page_bg'))
  }
}

@Component
export struct SettingsPage {
  @State page: number = PAGE_ROOT;
  onOpenAbout: () => void = () => {
  };

  private pageTitle(): Resource {
    if (this.page === PAGE_DETECTION) {
      return $r('app.string.settings_core');
    }
    if (this.page === PAGE_LANGUAGE) {
      return $r('app.string.settings_language');
    }
    if (this.page === PAGE_APPEARANCE) {
      return $r('app.string.settings_appearance');
    }
    return $r('app.string.settings');
  }

  build() {
    NavDestination() {
      SettingsView({
        page: this.page,
        onOpenAbout: this.onOpenAbout,
        onOpenPage: (page: number) => {
          this.page = page;
        }
      })
    }
    .title(this.pageTitle(), {
      barStyle: BarStyle.STANDARD,
      backgroundColor: $r('app.color.sidebar_bg')
    })
    .onBackPressed(() => {
      if (this.page !== PAGE_ROOT) {
        this.page = PAGE_ROOT;
        return true;
      }
      return false;
    })
    .backgroundColor($r('app.color.page_bg'))
  }
}
