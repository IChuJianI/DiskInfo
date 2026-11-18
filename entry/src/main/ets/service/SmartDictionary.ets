import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import { hexId } from './Format';
import { systemLanguage } from './Theme';

class LangFile {
  Smart: Record<string, string> = {};
  SmartSsd: Record<string, string> = {};
  SmartNVMe: Record<string, string> = {};
}

export class SmartDictionary {
  private zh: LangFile = new LangFile();
  private hant: LangFile = new LangFile();
  private en: LangFile = new LangFile();
  private mode: string = 'zh';

  load(context: common.Context, language: string): void {
    this.zh = this.read(context, 'smart/zh.json');
    this.hant = this.read(context, 'smart/zh-Hant.json');
    this.en = this.read(context, 'smart/en.json');
    if (this.hant.Smart['01'] === undefined) {
      this.hant = this.zh;
    }
    this.mode = this.resolveMode(context, language);
  }

  setLanguage(context: common.Context, language: string): void {
    this.mode = this.resolveMode(context, language);
  }

  active(): LangFile {
    if (this.mode === 'hant') {
      return this.hant;
    }
    return this.mode === 'en' ? this.en : this.zh;
  }

  attributeName(smartKey: string, id: number): string {
    const file = this.active();
    const key = hexId(id);
    let text = this.pick(file, smartKey, key);
    if (text.length === 0 && smartKey !== 'SmartNVMe') {
      text = this.pick(file, 'SmartSsd', key);
    }
    if (text.length === 0 && smartKey !== 'Smart') {
      text = this.pick(file, 'Smart', key);
    }
    if (text.length === 0) {
      text = this.mode === 'en' ? 'Vendor Specific' :
        (this.mode === 'hant' ? '由廠商定義' : '由厂商定义');
    }
    return text;
  }

  private pick(file: LangFile, section: string, key: string): string {
    if (section === 'SmartNVMe') {
      return file.SmartNVMe[key] !== undefined ? file.SmartNVMe[key] : '';
    }
    if (section === 'SmartSsd') {
      return file.SmartSsd[key] !== undefined ? file.SmartSsd[key] : '';
    }
    return file.Smart[key] !== undefined ? file.Smart[key] : '';
  }

  private read(context: common.Context, name: string): LangFile {
    try {
      const bytes = context.resourceManager.getRawFileContentSync(name);
      const decoder = util.TextDecoder.create('utf-8');
      const text = decoder.decodeToString(bytes);
      return JSON.parse(text) as LangFile;
    } catch (error) {
      return new LangFile();
    }
  }

  private resolveMode(context: common.Context, language: string): string {
    if (language === 'zh') {
      return 'zh';
    }
    if (language === 'zh-Hant') {
      return 'hant';
    }
    if (language === 'en' || language === 'ja' || language === 'ko' || language === 'ru') {
      return 'en';
    }
    let tag = systemLanguage().toLowerCase();
    if (tag === 'default') {
      try {
        const locales = context.resourceManager.getLocales();
        tag = locales.length > 0 ? locales[0].toLowerCase() : 'zh';
      } catch (error) {
        tag = 'zh';
      }
    }
    if (tag.startsWith('zh')) {
      if (tag.indexOf('hant') >= 0 || tag.indexOf('tw') >= 0 ||
        tag.indexOf('hk') >= 0 || tag.indexOf('mo') >= 0) {
        return 'hant';
      }
      return 'zh';
    }
    return 'en';
  }
}
