import { common, ConfigurationConstant } from '@kit.AbilityKit';
import i18n from '@ohos.i18n';

export const ACCENT_BLUE: string = '#0A59F7';
export const ACCENT_RED: string = '#D93025';
export const ACCENT_PURPLE: string = '#7B4DFF';
export const ACCENT_TEAL: string = '#0E9888';

export function systemLanguage(): string {
  try {
    const language = i18n.System.getSystemLanguage();
    if (language.length === 0) {
      return 'default';
    }
    if (language.startsWith('zh')) {
      let traditional = language.indexOf('Hant') >= 0 || language.indexOf('hant') >= 0 ||
        language.indexOf('TW') >= 0 || language.indexOf('HK') >= 0 || language.indexOf('MO') >= 0;
      if (!traditional) {
        const region = i18n.System.getSystemRegion();
        traditional = region === 'TW' || region === 'HK' || region === 'MO';
      }
      return traditional ? 'zh-Hant' : 'zh-Hans';
    }
    return language;
  } catch (error) {
    return 'default';
  }
}

export function accentColor(name: string): string {
  if (name === 'red') {
    return ACCENT_RED;
  }
  if (name === 'purple') {
    return ACCENT_PURPLE;
  }
  if (name === 'teal') {
    return ACCENT_TEAL;
  }
  return ACCENT_BLUE;
}

export function accentBgColor(name: string): string {
  if (name === 'red') {
    return '#1FD93025';
  }
  if (name === 'purple') {
    return '#1F7B4DFF';
  }
  if (name === 'teal') {
    return '#1F0E9888';
  }
  return '#1F0A59F7';
}

export function preferredLanguage(language: string): string {
  if (language === 'zh') {
    return 'zh-Hans';
  }
  if (language === 'zh-Hant') {
    return 'zh-Hant';
  }
  if (language === 'en') {
    return 'en-US';
  }
  if (language === 'ja') {
    return 'ja-JP';
  }
  if (language === 'ko') {
    return 'ko-KR';
  }
  if (language === 'ru') {
    return 'ru-RU';
  }
  return systemLanguage();
}

export function setAppThemeMode(context: common.Context, mode: string): void {
  let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  if (mode === 'dark') {
    colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  } else if (mode === 'light') {
    colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  try {
    context.getApplicationContext().setColorMode(colorMode);
  } catch (error) {
  }
}
