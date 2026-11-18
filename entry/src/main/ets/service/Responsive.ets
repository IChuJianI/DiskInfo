import deviceInfo from '@ohos.deviceInfo';

export function isPcDevice(): boolean {
  const type: string = deviceInfo.deviceType;
  return type === '2in1' || type === 'pc';
}

export enum Breakpoint {
  Sm = 0,
  Md = 1,
  Lg = 2
}

export function breakpointForWidth(width: number): number {
  if (width < 600) {
    return Breakpoint.Sm;
  }
  return width >= 840 ? Breakpoint.Lg : Breakpoint.Md;
}

export class ShellSpec {
  static readonly SIDEBAR_WIDTH: number = 280;
  static readonly TAB_BAR_WIDTH_SMALL: number = 328;
  static readonly TAB_BAR_WIDTH_MEDIUM: number = 360;
  static readonly TAB_BAR_WIDTH_LARGE: number = 420;
  static readonly TAB_BAR_SIDE_MARGIN: number = 16;
  static readonly TAB_BAR_BOTTOM_GAP: number = 16;
}

export class Layout {
  /** 官方控件圆角：电脑 8vp，手机 / 平板 20vp */
  static controlRadius(): number {
    return isPcDevice() ? 8 : 20;
  }

  static pagePadding(breakpoint: number): number {
    if (breakpoint === Breakpoint.Sm) {
      return 16;
    }
    return breakpoint === Breakpoint.Md ? 20 : 24;
  }

  static cardPadding(breakpoint: number): number {
    return breakpoint === Breakpoint.Sm ? 16 : 18;
  }

  static pageGap(breakpoint: number): number {
    return breakpoint === Breakpoint.Sm ? 12 : 14;
  }
}
