// UI工具类 - 封装 promptAction/router API
import { promptAction, router, UIContext } from '@kit.ArkUI';

// 路由参数
export class RouteParams {
  episodeId?: string;
  podcastId?: string;
}

// 按钮配置
export class ButtonOptions {
  text: string = '';
  color?: string;

  constructor(text: string, color?: string) {
    this.text = text;
    this.color = color; // 不指定时使用系统默认色，自动适配深色模式
  }
}

// Toast配置
export class ToastOptions {
  message: string = '';
  duration: number = 2000;

  constructor(message: string, duration?: number) {
    this.message = message;
    this.duration = duration || 2000;
  }
}

// Dialog配置
export class DialogOptions {
  title: string = '';
  message: string = '';
  buttons: ButtonOptions[] = [];

  constructor(title?: string, message?: string, buttons?: ButtonOptions[]) {
    this.title = title || '';
    this.message = message || '';
    this.buttons = buttons || [];
  }
}

// ActionMenu配置
export class ActionMenuOptions {
  title: string = '';
  buttons: ButtonOptions[] = [];

  constructor(title?: string, buttons?: ButtonOptions[]) {
    this.title = title || '';
    this.buttons = buttons || [];
  }
}

export class UIUtils {
  private static uiContext: UIContext | null = null;

  // 页面初始化时调用
  static setUIContext(context: UIContext): void {
    UIUtils.uiContext = context;
  }

  static showToast(options: ToastOptions): void {
    try {
      if (UIUtils.uiContext) {
        UIUtils.uiContext.getPromptAction().showToast({
          message: options.message,
          duration: options.duration
        });
      } else {
        // fallback
        promptAction.showToast({
          message: options.message,
          duration: options.duration
        });
      }
    } catch (error) {
      console.error('[UIUtils] showToast failed:', error);
    }
  }

  static async showDialog(options: DialogOptions): Promise<number> {
    try {
      // 转换按钮类型
      const dialogButtons: promptAction.Button[] = options.buttons.map(btn => {
        const dialogBtn: promptAction.Button = {
          text: btn.text,
          color: btn.color || '#007DFF' // 系统默认蓝色
        };
        return dialogBtn;
      });
      
      let result: promptAction.ShowDialogSuccessResponse;
      if (UIUtils.uiContext) {
        result = await UIUtils.uiContext.getPromptAction().showDialog({
          title: options.title,
          message: options.message,
          buttons: dialogButtons
        });
      } else {
        result = await promptAction.showDialog({
          title: options.title,
          message: options.message,
          buttons: dialogButtons
        });
      }
      return result.index;
    } catch (error) {
      console.error('[UIUtils] showDialog failed:', error);
      return -1;
    }
  }

  static async showActionMenu(options: ActionMenuOptions): Promise<number> {
    try {
      const len = options.buttons.length;
      if (len === 0 || len > 6) {
        console.error('[UIUtils] showActionMenu: buttons length must be 1-6');
        return -1;
      }
      
      // 构建按钮，只包含实际存在的按钮
      const makeBtn = (idx: number): promptAction.Button | undefined => {
        if (idx < len) {
          return { text: options.buttons[idx].text, color: options.buttons[idx].color || '#007DFF' };
        }
        return undefined;
      };
      
      let result: promptAction.ActionMenuSuccessResponse;
      const menuOptions: promptAction.ActionMenuOptions = {
        title: options.title,
        buttons: [makeBtn(0)!] as [promptAction.Button]
      };
      
      // 根据按钮数量动态构建
      if (len === 1) {
        menuOptions.buttons = [makeBtn(0)!];
      } else if (len === 2) {
        menuOptions.buttons = [makeBtn(0)!, makeBtn(1)];
      } else if (len === 3) {
        menuOptions.buttons = [makeBtn(0)!, makeBtn(1), makeBtn(2)];
      } else if (len === 4) {
        menuOptions.buttons = [makeBtn(0)!, makeBtn(1), makeBtn(2), makeBtn(3)];
      } else if (len === 5) {
        menuOptions.buttons = [makeBtn(0)!, makeBtn(1), makeBtn(2), makeBtn(3), makeBtn(4)];
      } else if (len === 6) {
        menuOptions.buttons = [makeBtn(0)!, makeBtn(1), makeBtn(2), makeBtn(3), makeBtn(4), makeBtn(5)];
      }
      
      if (UIUtils.uiContext) {
        result = await UIUtils.uiContext.getPromptAction().showActionMenu(menuOptions);
      } else {
        result = await promptAction.showActionMenu(menuOptions);
      }
      return result.index;
    } catch (error) {
      console.error('[UIUtils] showActionMenu failed:', error);
      return -1;
    }
  }

  static pushUrl(url: string, params?: RouteParams): void {
    try {
      // 转换参数格式
      let routerParams: Record<string, Object> | undefined = undefined;
      if (params) {
        routerParams = {};
        if (params.episodeId !== undefined) {
          routerParams['episodeId'] = params.episodeId;
        }
        if (params.podcastId !== undefined) {
          routerParams['podcastId'] = params.podcastId;
        }
      }
      router.pushUrl({
        url: url,
        params: routerParams
      }).catch((err: Error) => {
        console.error('[UIUtils] Navigation failed:', err);
      });
    } catch (error) {
      console.error('[UIUtils] pushUrl failed:', error);
    }
  }

  static back(): void {
    try {
      router.back();
    } catch (error) {
      console.error('[UIUtils] back failed:', error);
    }
  }

  static getParams<T>(): T | null {
    try {
      return router.getParams() as T;
    } catch (error) {
      console.error('[UIUtils] getParams failed:', error);
      return null;
    }
  }
}
