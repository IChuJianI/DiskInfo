import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import preferences from '@ohos.data.preferences';
import i18n from '@ohos.i18n';
import { preferredLanguage, setAppThemeMode, systemLanguage } from '../service/Theme';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyColorMode();
    this.applyPreferredLanguage();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private applyColorMode(): void {
    try {
      const store = preferences.getPreferencesSync(this.context, { name: 'diskinfo_settings_v1' });
      const value = store.getSync('themeMode', '');
      let mode = typeof value === 'string' && value.length > 0 ? value : 'auto';
      if (mode === 'auto' && !store.hasSync('themeMode') && store.hasSync('darkMode')) {
        const legacy = store.getSync('darkMode', false);
        mode = typeof legacy === 'boolean' && legacy ? 'dark' : 'light';
      }
      setAppThemeMode(this.context, mode);
    } catch (error) {
      setAppThemeMode(this.context, 'auto');
      hilog.warn(DOMAIN, 'testTag', 'Failed to apply color mode');
    }
  }

  private applyPreferredLanguage(): void {
    try {
      const store = preferences.getPreferencesSync(this.context, { name: 'diskinfo_settings_v1' });
      const value = store.getSync('language', 'auto');
      const language = typeof value === 'string' ? value : 'auto';
      i18n.System.setAppPreferredLanguage(preferredLanguage(language));
    } catch (error) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to apply preferred language');
    }
  }

  private followSystemLanguage(): void {
    try {
      const store = preferences.getPreferencesSync(this.context, { name: 'diskinfo_settings_v1' });
      const value = store.getSync('language', 'auto');
      if (typeof value !== 'string' || value !== 'auto') {
        return;
      }
      const resolved = systemLanguage();
      if (resolved === 'default' || this.sameLanguage(i18n.System.getAppPreferredLanguage(), resolved)) {
        return;
      }
      i18n.System.setAppPreferredLanguage(resolved);
    } catch (error) {
    }
  }

  private sameLanguage(current: string, resolved: string): boolean {
    const left = current.toLowerCase();
    const right = resolved.toLowerCase();
    if (right === 'zh-hans' || right === 'zh-hant') {
      return left === right;
    }
    return left.substring(0, 2) === right.substring(0, 2);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    try {
      windowStage.getMainWindowSync().setWindowLayoutFullScreen(false).catch((error: Error) => {
        hilog.warn(DOMAIN, 'testTag', 'Failed to disable immersive layout. Cause: %{public}s', error.message);
      });
    } catch (error) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to get the main window');
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.followSystemLanguage();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}