import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'diskinfo_settings_v1';

export class AppSettings {
  refreshSeconds: number = 10;
  useCelsius: boolean = true;
  alarmTemperature: number = 55;
  threshold05: number = 1;
  thresholdC5: number = 1;
  thresholdC6: number = 1;
  thresholdFF: number = 10;
  rawHexadecimal: boolean = false;
  hideSerial: boolean = false;
  language: string = 'auto';
  themeMode: string = 'auto';
  accentColor: string = 'blue';
}

export class SettingsService {
  private store: preferences.Preferences | null = null;

  open(context: common.Context): void {
    try {
      this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (error) {
      this.store = null;
    }
  }

  load(): AppSettings {
    const settings = new AppSettings();
    if (this.store === null) {
      return settings;
    }
    settings.refreshSeconds = this.number('refreshSeconds', settings.refreshSeconds);
    settings.useCelsius = this.boolean('useCelsius', settings.useCelsius);
    settings.alarmTemperature = this.number('alarmTemperature', settings.alarmTemperature);
    settings.threshold05 = this.number('threshold05', settings.threshold05);
    settings.thresholdC5 = this.number('thresholdC5', settings.thresholdC5);
    settings.thresholdC6 = this.number('thresholdC6', settings.thresholdC6);
    settings.thresholdFF = this.number('thresholdFF', settings.thresholdFF);
    settings.rawHexadecimal = this.boolean('rawHexadecimal', settings.rawHexadecimal);
    settings.hideSerial = this.boolean('hideSerial', settings.hideSerial);
    settings.language = this.text('language', settings.language);
    settings.themeMode = this.text('themeMode', '');
    if (settings.themeMode.length === 0) {
      settings.themeMode = this.has('darkMode') ? (this.boolean('darkMode', false) ? 'dark' : 'light') : 'auto';
    }
    settings.accentColor = this.text('accentColor', settings.accentColor);
    return settings;
  }

  save(settings: AppSettings): void {
    if (this.store === null) {
      return;
    }
    try {
      this.store.putSync('refreshSeconds', settings.refreshSeconds);
      this.store.putSync('useCelsius', settings.useCelsius);
      this.store.putSync('alarmTemperature', settings.alarmTemperature);
      this.store.putSync('threshold05', settings.threshold05);
      this.store.putSync('thresholdC5', settings.thresholdC5);
      this.store.putSync('thresholdC6', settings.thresholdC6);
      this.store.putSync('thresholdFF', settings.thresholdFF);
      this.store.putSync('rawHexadecimal', settings.rawHexadecimal);
      this.store.putSync('hideSerial', settings.hideSerial);
      this.store.putSync('language', settings.language);
      this.store.putSync('themeMode', settings.themeMode);
      this.store.putSync('accentColor', settings.accentColor);
      this.store.flushSync();
    } catch (error) {
      this.store = null;
    }
  }

  private number(key: string, fallback: number): number {
    if (this.store === null) {
      return fallback;
    }
    try {
      const value = this.store.getSync(key, fallback);
      return typeof value === 'number' ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }

  private boolean(key: string, fallback: boolean): boolean {
    if (this.store === null) {
      return fallback;
    }
    try {
      const value = this.store.getSync(key, fallback);
      return typeof value === 'boolean' ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }

  private has(key: string): boolean {
    if (this.store === null) {
      return false;
    }
    try {
      return this.store.hasSync(key);
    } catch (error) {
      return false;
    }
  }

  private text(key: string, fallback: string): string {
    if (this.store === null) {
      return fallback;
    }
    try {
      const value = this.store.getSync(key, fallback);
      return typeof value === 'string' ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }
}
