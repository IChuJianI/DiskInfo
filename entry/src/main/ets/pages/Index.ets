import { common } from '@kit.AbilityKit';
import { uiMaterial, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  DiskScanOutcome,
  HEALTH_BAD,
  HEALTH_CAUTION,
  HEALTH_GOOD,
  NativeDisk
} from '../model/DiskModels';
import { DiskListItem, InfoEntry, SmartRow } from '../model/ViewModels';
import { DiskRepository } from '../service/DiskRepository';
import { UsbDiskProbe } from '../service/UsbDiskProbe';
import { formatBytes, formatNumber, formatRaw, formatTemperature, hexId } from '../service/Format';
import { AppSettings, SettingsService } from '../service/SettingsService';
import { SmartDictionary } from '../service/SmartDictionary';
import { DiskSidebar } from '../components/DiskSidebar';
import { OverviewCards } from '../components/OverviewCards';
import { DeviceInfoGrid } from '../components/DeviceInfoGrid';
import { SmartTable } from '../components/SmartTable';
import { ThermalChart } from '../components/ThermalChart';
import { Breakpoint, breakpointForWidth, Layout, ShellSpec, isPcDevice } from '../service/Responsive';
import { SettingsPage } from './SettingsPage';
import { accentBgColor, accentColor } from '../service/Theme';
import { AboutPage } from './AboutPage';
import { DiagnosticsPage } from './DiagnosticsPage';

const ROUTE_MAIN: string = 'main';
const ROUTE_SETTINGS: string = 'settings';
const ROUTE_ABOUT: string = 'about';
const ROUTE_DIAGNOSTICS: string = 'diagnostics';

const TAB_HOME: number = 0;
const TAB_DISKS: number = 1;

@Entry
@Component
struct Index {
  @StorageLink('diskinfoSettings') @Watch('onSettingsChanged') settings: AppSettings = new AppSettings();
  @StorageLink('diskinfoBreakpoint') breakpoint: number = Breakpoint.Lg;
  @State disks: NativeDisk[] = [];
  @State selectedNode: string = '';
  @State scanning: boolean = false;
  @State lastScan: string = '';
  @State messages: string[] = [];
  @State history: number[] = [];
  @State currentTab: number = TAB_HOME;
  @State showHome: boolean = true;
  private mobileStack: NavPathStack = new NavPathStack();
  private desktopStack: NavPathStack = new NavPathStack();
  private dictionary: SmartDictionary = new SmartDictionary();
  private settingsService: SettingsService = new SettingsService();
  private pcShell: boolean = isPcDevice();
  private context: common.Context | null = null;
  private timerId: number = -1;
  private scanTimerId: number = -1;
  private hotplugTimerId: number = -1;
  private deviceSignature: string = '';
  private lastRefreshSeconds: number = 10;
  private lastLanguage: string = 'auto';
  private lastThresholds: string = '';
  private histories: Map<string, number[]> = new Map();
  private initialized: boolean = false;

  aboutToAppear(): void {
    const host = this.getUIContext().getHostContext();
    if (host !== undefined) {
      this.context = host as common.Context;
      this.settingsService.open(this.context);
      const loaded = this.settingsService.load();
      this.dictionary.load(this.context, loaded.language);
      AppStorage.setOrCreate('diskinfoSettings', loaded);
      this.settings = loaded;
      this.lastRefreshSeconds = loaded.refreshSeconds;
      this.lastLanguage = loaded.language;
      this.lastThresholds = this.thresholdSignature(loaded);
    }
    AppStorage.setOrCreate('diskinfoMessages', []);
    this.initialized = true;
    if (this.pcShell) {
      this.desktopStack.pushPath(new NavPathInfo(ROUTE_MAIN, null));
    }
    this.startTimer();
    this.startHotplugWatch();
    this.scan();
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.scanTimerId >= 0) {
      clearTimeout(this.scanTimerId);
      this.scanTimerId = -1;
    }
    if (this.hotplugTimerId >= 0) {
      clearInterval(this.hotplugTimerId);
      this.hotplugTimerId = -1;
    }
  }

  onBackPress(): boolean {
    if (this.activeStack().size() > 0) {
      return false;
    }
    if (!this.sidebarLayout() && this.currentTab !== TAB_HOME) {
      this.currentTab = TAB_HOME;
      return true;
    }
    return false;
  }

  // ── 壳层：≥840vp 用侧边栏，否则手机 / 平板外壳（电脑缩放窗口同样生效） ──

  /** 断点直接读窗口实际宽度：媒体查询在 2in1 上不跟随窗口缩放 */
  private updateBreakpoint(width: number): void {
    const next: number = breakpointForWidth(width);
    if (next === this.breakpoint) {
      return;
    }
    this.breakpoint = next;
    this.syncShellStacks();
  }

  private sidebarLayout(): boolean {
    return this.pcShell && this.breakpoint === Breakpoint.Lg;
  }

  private activeStack(): NavPathStack {
    return this.sidebarLayout() ? this.desktopStack : this.mobileStack;
  }

  private sameRoutes(a: string[], b: string[]): boolean {
    if (a.length !== b.length) {
      return false;
    }
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) {
        return false;
      }
    }
    return true;
  }

  /** 两套外壳各有自己的栈：跨 840vp 时把当前可见路由搬到目标栈 */
  private syncShellStacks(): void {
    if (this.sidebarLayout()) {
      this.showHome = this.currentTab === TAB_HOME;
      const names: string[] = this.mobileStack.getAllPathName();
      const target: string[] = [ROUTE_MAIN];
      for (let i = 0; i < names.length; i++) {
        if (names[i] !== ROUTE_MAIN) {
          target.push(names[i]);
        }
      }
      if (!this.sameRoutes(this.desktopStack.getAllPathName(), target)) {
        this.desktopStack.clear();
        for (let i = 0; i < target.length; i++) {
          this.desktopStack.pushPath(new NavPathInfo(target[i], null));
        }
      }
      this.mobileStack.clear();
      return;
    }
    const names: string[] = this.desktopStack.getAllPathName();
    if (names.length === 0) {
      return;
    }
    this.currentTab = this.showHome ? TAB_HOME : TAB_DISKS;
    const target: string[] = [];
    for (let i = 0; i < names.length; i++) {
      if (names[i] !== ROUTE_MAIN) {
        target.push(names[i]);
      }
    }
    if (!this.sameRoutes(this.mobileStack.getAllPathName(), target)) {
      this.mobileStack.clear();
      for (let i = 0; i < target.length; i++) {
        this.mobileStack.pushPath(new NavPathInfo(target[i], null));
      }
    }
    this.desktopStack.clear();
  }

  private pushDesktopPage(name: string): void {
    if (this.desktopStack.size() === 0) {
      this.desktopStack.pushPath(new NavPathInfo(ROUTE_MAIN, null));
    } else if (this.desktopStack.size() > 1) {
      this.desktopStack.popToIndex(0);
    }
    this.desktopStack.pushPath(new NavPathInfo(name, null));
  }

  private tabBarStyle(label: Resource, icon: Resource): BottomTabBarStyle {
    const normal = new SymbolGlyphModifier(icon);
    normal.fontColor([$r('app.color.text_secondary')]);
    const selected = new SymbolGlyphModifier(icon);
    selected.fontColor([accentColor(this.settings.accentColor)]);
    const symbol: TabBarSymbol = {
      normal: normal,
      selected: selected
    };
    return BottomTabBarStyle.of(symbol, this.text(label.id))
      .labelStyle({
        selectedColor: accentColor(this.settings.accentColor),
        unselectedColor: $r('app.color.text_secondary'),
        maxLines: 1
      });
  }

  private tabBarMaterial(): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      lightEffect: { color: accentColor(this.settings.accentColor) }
    });
  }

  private pageTitle(): Resource {
    const home: boolean = this.sidebarLayout() ? this.showHome : this.currentTab === TAB_HOME;
    return home ? $r('app.string.home') : $r('app.string.disks');
  }

  private titleOptions(): NavigationTitleOptions {
    return {
      barStyle: BarStyle.STANDARD,
      backgroundColor: $r('app.color.sidebar_bg')
    };
  }

  private refreshMenu(): NavigationMenuItem {
    return {
      value: $r('app.string.refresh'),
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_clockwise'))
        .fontSize(22)
        .fontColor([$r('app.color.text_primary')]),
      isEnabled: !this.scanning,
      action: (): void => {
        this.scan();
      }
    };
  }

  private diagnosticsMenu(): NavigationMenuItem {
    return {
      value: $r('app.string.diagnostics'),
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.stethoscope'))
        .fontSize(22)
        .fontColor([$r('app.color.text_primary')]),
      action: (): void => {
        this.openDiagnostics();
      }
    };
  }

  private settingsMenu(): NavigationMenuItem {
    return {
      value: $r('app.string.settings'),
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape'))
        .fontSize(22)
        .fontColor([$r('app.color.text_primary')]),
      action: (): void => {
        this.openSettings();
      }
    };
  }

  /** 三端一致：刷新 / 诊断 / 设置都在官方标题栏右上角 */
  private topMenus(): NavigationMenuItem[] {
    return [this.refreshMenu(), this.diagnosticsMenu(), this.settingsMenu()];
  }

  private onSettingsChanged(): void {
    if (!this.initialized) {
      return;
    }
    const next = this.settings;
    if (this.context !== null && next.language !== this.lastLanguage) {
      this.lastLanguage = next.language;
      this.dictionary.setLanguage(this.context, next.language);
    }
    if (next.refreshSeconds !== this.lastRefreshSeconds) {
      this.lastRefreshSeconds = next.refreshSeconds;
      this.startTimer();
    }
    const thresholds = this.thresholdSignature(next);
    if (thresholds !== this.lastThresholds) {
      this.lastThresholds = thresholds;
      this.scheduleScan();
    }
  }

  private thresholdSignature(settings: AppSettings): string {
    return settings.threshold05.toString() + '/' + settings.thresholdC5.toString() + '/' +
      settings.thresholdC6.toString() + '/' + settings.thresholdFF.toString();
  }

  private scheduleScan(): void {
    if (this.scanTimerId >= 0) {
      clearTimeout(this.scanTimerId);
    }
    this.scanTimerId = setTimeout(() => {
      this.scanTimerId = -1;
      this.scan();
    }, 400);
  }

  private startTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    const seconds = this.settings.refreshSeconds > 0 ? this.settings.refreshSeconds : 10;
    this.timerId = setInterval(() => {
      this.scan();
    }, seconds * 1000);
  }

  // usbManager 没有热插拔事件，轮询设备表代价很低，1 秒内发现接入/拔出
  private startHotplugWatch(): void {
    if (this.hotplugTimerId >= 0) {
      clearInterval(this.hotplugTimerId);
      this.hotplugTimerId = -1;
    }
    this.hotplugTimerId = setInterval(() => {
      if (this.scanning) {
        return;
      }
      if (UsbDiskProbe.signature() !== this.deviceSignature) {
        this.scan();
      }
    }, 1000);
  }

  private async scan(): Promise<void> {
    if (this.scanning) {
      return;
    }
    this.scanning = true;
    this.deviceSignature = UsbDiskProbe.signature();
    try {
      const outcome: DiskScanOutcome = await DiskRepository.scan(this.settings);
      this.disks = outcome.disks;
      this.messages = outcome.messages;
      AppStorage.setOrCreate('diskinfoMessages', outcome.messages);
      if (!this.containsNode(this.selectedNode)) {
        this.selectedNode = this.disks.length > 0 ? this.disks[0].node : '';
      }
      this.lastScan = this.clock();
      this.sampleHistory();
    } catch (error) {
      this.messages = [(error as Error).message];
    } finally {
      this.scanning = false;
    }
  }

  private containsNode(node: string): boolean {
    if (node.length === 0) {
      return false;
    }
    for (const disk of this.disks) {
      if (disk.node === node) {
        return true;
      }
    }
    return false;
  }

  private clock(): string {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    const seconds = now.getSeconds().toString().padStart(2, '0');
    return hours + ':' + minutes + ':' + seconds;
  }

  private selectDisk(node: string): void {
    this.selectedNode = node;
    this.showHome = false;
    const stored = this.histories.get(node);
    this.history = stored !== undefined ? stored.slice(0) : [];
    if (this.desktopStack.size() > 1) {
      this.desktopStack.popToIndex(0);
    }
  }

  private openHome(): void {
    this.showHome = true;
    if (this.desktopStack.size() > 1) {
      this.desktopStack.popToIndex(0);
    }
  }

  private sampleHistory(): void {
    if (this.disks.length === 0 || this.selectedNode.length === 0) {
      return;
    }
    const disk = this.currentDisk();
    if (disk.temperature < 0) {
      return;
    }
    const stored = this.histories.get(this.selectedNode);
    const list = stored !== undefined ? stored.slice(0) : [];
    list.push(disk.temperature);
    while (list.length > 60) {
      list.shift();
    }
    this.histories.set(this.selectedNode, list);
    this.history = list.slice(0);
  }

  private currentDisk(): NativeDisk {
    for (const disk of this.disks) {
      if (disk.node === this.selectedNode) {
        return disk;
      }
    }
    return this.disks[0];
  }

  private text(id: number): string {
    if (this.context === null) {
      return '';
    }
    try {
      return this.context.resourceManager.getStringSync(id);
    } catch (error) {
      return '';
    }
  }

  private healthText(health: number): string {
    if (health === HEALTH_GOOD) {
      return this.text($r('app.string.status_good').id);
    }
    if (health === HEALTH_CAUTION) {
      return this.text($r('app.string.status_caution').id);
    }
    if (health === HEALTH_BAD) {
      return this.text($r('app.string.status_bad').id);
    }
    return this.text($r('app.string.status_unknown').id);
  }

  private healthColor(health: number): Resource {
    if (health === HEALTH_GOOD) {
      return $r('app.color.good');
    }
    if (health === HEALTH_CAUTION) {
      return $r('app.color.caution');
    }
    if (health === HEALTH_BAD) {
      return $r('app.color.bad');
    }
    return $r('app.color.unknown');
  }

  private busText(disk: NativeDisk): string {
    if (disk.bus === 'nvme') {
      return this.text($r('app.string.bus_nvme').id);
    }
    if (disk.bus === 'usb') {
      return this.text($r('app.string.bus_usb').id);
    }
    if (disk.bus === 'ata') {
      return this.text($r('app.string.bus_ata').id);
    }
    return this.text($r('app.string.bus_unknown').id);
  }

  private modelText(disk: NativeDisk): string {
    return disk.model.length > 0 ? disk.model : '---';
  }

  private capacityText(disk: NativeDisk): string {
    return disk.capacityBytes > 0 ? formatBytes(disk.capacityBytes) :
      this.text($r('app.string.value_na').id);
  }

  private temperatureText(disk: NativeDisk): string {
    return formatTemperature(disk.temperature, this.settings.useCelsius);
  }

  private lifeText(disk: NativeDisk): string {
    return disk.life >= 0 ? disk.life.toString() + ' %' : this.text($r('app.string.value_na').id);
  }

  private hoursText(disk: NativeDisk): string {
    if (!disk.powerOnHoursKnown) {
      return this.text($r('app.string.value_na').id);
    }
    if (disk.powerOnHours > 0) {
      return formatNumber(disk.powerOnHours) + ' ' + this.text($r('app.string.unit_hours').id);
    }
    if (disk.powerOnMinutes > 0) {
      return formatNumber(disk.powerOnMinutes) + ' ' + this.text($r('app.string.unit_minutes').id);
    }
    if (disk.powerOnActive) {
      return this.text($r('app.string.power_on_under_minute').id);
    }
    return '0 ' + this.text($r('app.string.unit_hours').id);
  }

  private countText(disk: NativeDisk): string {
    if (disk.powerOnCount <= 0) {
      return this.text($r('app.string.value_na').id);
    }
    return formatNumber(disk.powerOnCount) + ' ' + this.text($r('app.string.unit_times').id);
  }

  private alarmActive(disk: NativeDisk): boolean {
    return disk.temperature >= 0 && disk.temperature >= this.settings.alarmTemperature;
  }

  private diskItems(): DiskListItem[] {
    const items: DiskListItem[] = [];
    for (const disk of this.disks) {
      const item = new DiskListItem();
      item.node = disk.node;
      item.title = this.modelText(disk);
      const bus = this.busText(disk);
      const capacity = disk.capacityBytes > 0 ? formatBytes(disk.capacityBytes) : '';
      item.subtitle = capacity.length > 0 ? bus + ' · ' + capacity : bus;
      item.health = disk.health;
      items.push(item);
    }
    return items;
  }

  private infoEntries(): InfoEntry[] {
    const disk = this.currentDisk();
    const entries: InfoEntry[] = [];
    this.addEntry(entries, $r('app.string.info_model').id, this.modelText(disk));
    this.addEntry(entries, $r('app.string.capacity').id, this.capacityText(disk));
    this.addEntry(entries, $r('app.string.info_bus').id, this.busText(disk));
    this.addEntry(entries, $r('app.string.info_interface').id,
      disk.interface.length > 0 ? disk.interface : this.busText(disk));
    this.addEntry(entries, $r('app.string.info_transfer').id, disk.transferMode);
    this.addEntry(entries, $r('app.string.info_form_factor').id, disk.formFactor);
    this.addEntry(entries, $r('app.string.info_rotation').id, this.rotationText(disk));
    this.addEntry(entries, $r('app.string.info_firmware').id, disk.firmware);
    this.addEntry(entries, $r('app.string.info_serial').id, this.serialText(disk));
    this.addEntry(entries, $r('app.string.info_features').id, disk.features);
    return entries;
  }

  private addEntry(entries: InfoEntry[], labelId: number, value: string): void {
    if (value.length === 0) {
      return;
    }
    const entry = new InfoEntry();
    entry.label = this.text(labelId);
    entry.value = value;
    entries.push(entry);
  }

  private rotationText(disk: NativeDisk): string {
    if (disk.isSsd) {
      return this.text($r('app.string.rotation_ssd').id);
    }
    if (disk.rotationRate > 0) {
      const suffix = disk.rotationRateEstimated ?
        ' · ' + this.text($r('app.string.rotation_estimated').id) : '';
      return formatNumber(disk.rotationRate) + ' ' +
        this.text($r('app.string.unit_rpm').id) + suffix;
    }
    return this.text($r('app.string.rotation_hdd').id) + ' · ' +
      this.text($r('app.string.rotation_unreported').id);
  }

  private serialText(disk: NativeDisk): string {
    if (disk.serial.length === 0) {
      return '';
    }
    return this.settings.hideSerial ? '••••••••' : disk.serial;
  }

  private lastScanLine(): string {
    if (this.lastScan.length === 0) {
      return '';
    }
    return this.text($r('app.string.last_scan').id) + ' ' + this.lastScan;
  }

  private smartRows(): SmartRow[] {
    const disk = this.currentDisk();
    const rows: SmartRow[] = [];
    for (const attr of disk.attributes) {
      const row = new SmartRow();
      row.id = hexId(attr.id);
      row.name = this.dictionary.attributeName(disk.smartKey, attr.id);
      if (disk.smartKey === 'SmartNVMe') {
        row.current = '---';
        row.worst = '---';
        row.threshold = '---';
      } else {
        row.current = attr.current.toString();
        row.worst = attr.worst.toString();
        row.threshold = attr.threshold.toString();
        row.warn = attr.threshold > 0 && attr.current < attr.threshold;
      }
      row.raw = formatRaw(attr, disk.smartKey, this.settings.rawHexadecimal, this.settings.useCelsius);
      rows.push(row);
    }
    return rows;
  }

  private openSettings(): void {
    if (this.sidebarLayout()) {
      this.pushDesktopPage(ROUTE_SETTINGS);
    } else {
      this.mobileStack.pushPath(new NavPathInfo(ROUTE_SETTINGS, null));
    }
  }

  private openAbout(): void {
    if (this.sidebarLayout()) {
      if (this.desktopStack.size() === 0) {
        this.desktopStack.pushPath(new NavPathInfo(ROUTE_MAIN, null));
      }
      this.desktopStack.pushPath(new NavPathInfo(ROUTE_ABOUT, null));
    } else {
      this.mobileStack.pushPath(new NavPathInfo(ROUTE_ABOUT, null));
    }
  }

  private openDiagnostics(): void {
    AppStorage.setOrCreate('diskinfoMessages', this.messages);
    if (this.sidebarLayout()) {
      this.pushDesktopPage(ROUTE_DIAGNOSTICS);
    } else {
      this.mobileStack.pushPath(new NavPathInfo(ROUTE_DIAGNOSTICS, null));
    }
  }

  // ── 页面与外壳 ─────────────────────────────────────────

  @Builder
  pageMap(name: string) {
    if (name === ROUTE_MAIN) {
      this.desktopMain()
    } else if (name === ROUTE_SETTINGS) {
      SettingsPage({
        onOpenAbout: () => {
          this.openAbout();
        }
      })
    } else if (name === ROUTE_DIAGNOSTICS) {
      DiagnosticsPage()
    } else {
      AboutPage()
    }
  }

  @Builder
  desktopMain() {
    NavDestination() {
      if (this.showHome) {
        this.homeView()
      } else {
        this.dashboard()
      }
    }
    .title(this.pageTitle(), this.titleOptions())
    .hideBackButton(true)
    .menus(this.topMenus())
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  desktopShell() {
    Navigation(this.desktopStack) {
      DiskSidebar({
        items: this.diskItems(),
        selectedNode: this.selectedNode,
        homeSelected: this.showHome,
        disksSelected: !this.showHome,
        scanning: this.scanning,
        lastScan: this.lastScan,
        warningCount: this.messages.length,
        accentName: this.settings.accentColor,
        onSelect: (node: string) => {
          this.selectDisk(node);
        },
        onOpenHome: () => {
          this.openHome();
        },
        onOpenAbout: () => {
          this.openAbout();
        }
      })
    }
    .mode(NavigationMode.Split)
    .navBarWidth(ShellSpec.SIDEBAR_WIDTH)
    .navBarWidthRange([260, 360])
    .hideTitleBar(true)
    .hideBackButton(true)
    .navDestination(this.pageMap)
    .divider({ color: $r('app.color.divider'), startMargin: 0, endMargin: 0 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  mobileShell() {
    Navigation(this.mobileStack) {
      this.compactTabs()
    }
    .mode(NavigationMode.Stack)
    .title(this.pageTitle(), this.titleOptions())
    .titleMode(NavigationTitleMode.Mini)
    .hideBackButton(true)
    .menus(this.topMenus())
    .navDestination(this.pageMap)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  // ── 底部悬浮页签（手机 / 平板 / 窄窗口） ─────────────────

  @Builder
  compactTabs() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        this.homeView()
      }
      .tabBar(this.tabBarStyle($r('app.string.home'), $r('sys.symbol.house')))

      TabContent() {
        this.dashboard()
      }
      .tabBar(this.tabBarStyle($r('app.string.disks'), $r('sys.symbol.externaldrive')))
    }
    .width('100%')
    .height('100%')
    .barMode(BarMode.Fixed)
    .barOverlap(true)
    .barFloatingStyle({
      barWidth: {
        smallBarWidth: ShellSpec.TAB_BAR_WIDTH_SMALL,
        mediumBarWidth: ShellSpec.TAB_BAR_WIDTH_MEDIUM,
        largeBarWidth: ShellSpec.TAB_BAR_WIDTH_LARGE
      },
      barSideMargin: ShellSpec.TAB_BAR_SIDE_MARGIN,
      barBottomMargin: ShellSpec.TAB_BAR_BOTTOM_GAP,
      systemMaterial: this.tabBarMaterial()
    })
    .onChange((index: number) => {
      this.currentTab = index;
    })
  }

  // ── 首页：介绍与使用步骤 ───────────────────────────────

  @Builder
  homeHero() {
    Column({ space: 12 }) {
      Image($r('app.media.startIcon'))
        .width(80)
        .height(80)
        .borderRadius(22)
        .clip(true)
      Column({ space: 6 }) {
        Text('DiskInfo')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.app_tagline'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Center)
      Text($r('app.string.home_intro'))
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .constraintSize({ maxWidth: 520 })
    }
    .width('100%')
    .padding({ top: 24, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  homeStep(step: string, title: Resource, desc: Resource) {
    Row({ space: 12 }) {
      Stack() {
        Text(step)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(accentColor(this.settings.accentColor))
      }
      .width(28)
      .height(28)
      .borderRadius(14)
      .backgroundColor(accentBgColor(this.settings.accentColor))
      .accessibilityLevel('no')

      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(desc)
          .fontSize(13)
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 16, right: 16 })
    .alignItems(VerticalAlign.Top)
  }

  private openDisks(): void {
    if (this.sidebarLayout()) {
      if (this.disks.length > 0) {
        this.selectDisk(this.disks[0].node);
      } else {
        this.showHome = false;
      }
    } else {
      this.currentTab = TAB_DISKS;
    }
  }

  @Builder
  homeView() {
    Scroll() {
      Column() {
        Column({ space: 20 }) {
          this.homeHero()

          Column({ space: 8 }) {
            Text($r('app.string.home_steps_title'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            Column() {
              this.homeStep('1', $r('app.string.home_step_connect_title'),
                $r('app.string.home_step_connect_desc'))
              Divider()
                .strokeWidth(0.5)
                .color($r('app.color.divider'))
                .margin({ left: 56, right: 16 })
              this.homeStep('2', $r('app.string.home_step_read_title'),
                $r('app.string.home_step_read_desc'))
              Divider()
                .strokeWidth(0.5)
                .color($r('app.color.divider'))
                .margin({ left: 56, right: 16 })
              this.homeStep('3', $r('app.string.home_step_view_title'),
                $r('app.string.home_step_view_desc'))
            }
            .width('100%')
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(16)
          }
          .width('100%')

          Column({ space: 12 }) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.externaldrive'))
                  .fontSize(20)
                  .fontColor([Color.White])
                Text($r('app.string.home_cta'))
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
              }
            }
            .width('100%')
            .height(48)
            .backgroundColor(accentColor(this.settings.accentColor))
            .borderRadius(Layout.controlRadius())
            .onClick(() => {
              this.openDisks();
            })

            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.checkmark_shield'))
                .fontSize(14)
                .fontColor([$r('app.color.text_secondary')])
              Text($r('app.string.home_local_note'))
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxWidth: this.sidebarLayout() ? 840 : 720 })
      }
      .width('100%')
      .padding({
        left: Layout.pagePadding(this.breakpoint),
        right: Layout.pagePadding(this.breakpoint),
        top: Layout.pagePadding(this.breakpoint),
        bottom: this.sidebarLayout() ? 24 : 96
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Auto)
    .backgroundColor($r('app.color.page_bg'))
  }

  // ── 仪表盘内容 ─────────────────────────────────────────

  @Builder
  warningBanner() {
    Row({ space: 10 }) {
      Circle()
        .width(8)
        .height(8)
        .fill($r('app.color.caution'))
      Column({ space: 2 }) {
        Text($r('app.string.warnings'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.messages[0])
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button($r('app.string.diagnostics'))
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(32)
        .padding({ left: 12, right: 12 })
        .borderRadius(Layout.controlRadius())
        .backgroundColor($r('app.color.chip_bg'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => {
          this.openDiagnostics();
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.warn_bg'))
    .borderRadius(12)
  }

  @Builder
  smartUnavailable() {
    Column({ space: 8 }) {
      Text($r('app.string.smart_title'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text($r('app.string.smart_unavailable'))
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .lineHeight(18)
      Button($r('app.string.diagnostics'))
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(32)
        .padding({ left: 12, right: 12 })
        .borderRadius(Layout.controlRadius())
        .backgroundColor($r('app.color.chip_bg'))
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 4 })
        .onClick(() => {
          this.openDiagnostics();
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  diskChip(item: DiskListItem) {
    Row({ space: 6 }) {
      Circle()
        .width(7)
        .height(7)
        .fill(this.healthColor(item.health))
      Text(item.title)
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .borderRadius(14)
    .backgroundColor(this.selectedNode === item.node ? $r('app.color.card_bg') : $r('app.color.chip_bg'))
    .onClick(() => {
      this.selectDisk(item.node);
    })
  }

  @Builder
  mobileDiskHead() {
    Column({ space: 10 }) {
      if (this.diskItems().length > 1) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.diskItems(), (item: DiskListItem) => {
              this.diskChip(item)
            }, (item: DiskListItem) => item.node + item.title + item.subtitle)
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }

      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(this.modelText(this.currentDisk()))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.busText(this.currentDisk()) + ' · ' + this.capacityText(this.currentDisk()))
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 6 }) {
          Circle()
            .width(9)
            .height(9)
            .fill(this.healthColor(this.currentDisk().health))
          Text(this.healthText(this.currentDisk().health))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')

      if (this.lastScanLine().length > 0) {
        Text(this.lastScanLine())
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  dashboard() {
    Column() {
      if (this.disks.length === 0) {
        Column({ space: 10 }) {
          Text($r('app.string.no_disk'))
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
          Text($r('app.string.degraded_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: Layout.pageGap(this.breakpoint) }) {
            this.mobileDiskHead()
            if (this.messages.length > 0) {
              this.warningBanner()
            }
            OverviewCards({
              health: this.currentDisk().health,
              healthText: this.healthText(this.currentDisk().health),
              temperatureText: this.temperatureText(this.currentDisk()),
              temperatureAlarm: this.alarmActive(this.currentDisk()),
              lifeText: this.lifeText(this.currentDisk()),
              lifeEstimated: this.currentDisk().lifeEstimated,
              powerOnHoursText: this.hoursText(this.currentDisk()),
              powerOnCountText: this.countText(this.currentDisk())
            })
            DeviceInfoGrid({
              entries: this.infoEntries()
            })
            if (this.currentDisk().smartAvailable && this.history.length > 1) {
              ThermalChart({
                points: this.history,
                useCelsius: this.settings.useCelsius
              })
            }
            if (this.currentDisk().smartAvailable) {
              SmartTable({
                rows: this.smartRows()
              })
            } else {
              this.smartUnavailable()
            }
          }
          .width('100%')
          .padding({
            left: Layout.pagePadding(this.breakpoint),
            right: Layout.pagePadding(this.breakpoint),
            top: Layout.pagePadding(this.breakpoint),
            bottom: this.sidebarLayout() ? 24 : 96
          })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  build() {
    Stack() {
      if (this.sidebarLayout()) {
        this.desktopShell()
      } else {
        this.mobileShell()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const raw = newArea.width;
      let width: number = 0;
      if (typeof raw === 'number') {
        width = raw;
      } else if (typeof raw === 'string') {
        width = parseFloat(raw);
      }
      if (width > 0) {
        this.updateBreakpoint(width);
      }
    })
  }
}
