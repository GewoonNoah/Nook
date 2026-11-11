// The one toast for a short result (the Mac's ToastCenter): "Pull request gemaakt", "Verstuurd naar Lisa", or what
// failed. A queue with a clock, without UI code, so tests can use it on its own; `toast.svelte.ts` makes it reactive.

export type ToastKind = "success" | "error" | "warning" | "info";

/// One button on a toast that undoes or follows up what just happened ("Ongedaan maken").
export interface ToastAction {
  label: string;
  run: () => void;
}

export interface Toast {
  id: number;
  kind: ToastKind;
  title: string;
  detail?: string;
  action?: ToastAction;
}

/// How long a toast stays by itself: an error is read more slowly than a confirmation.
export const TOAST_SECONDS: Record<ToastKind, number> = { success: 3.5, info: 3.5, warning: 5, error: 7 };

/// Toasts take turns: one shows, the rest wait. The same message twice only restarts the clock of the first.
export class ToastQueue {
  current: Toast | null = null;
  private waiting: Toast[] = [];
  private left = 0;
  private nextId = 1;

  constructor(private readonly changed: (current: Toast | null) => void = () => {}) {}

  show(title: string, kind: ToastKind = "info", detail?: string, action?: ToastAction) {
    const text = title.trim();
    if (!text) return;
    const toast: Toast = { id: this.nextId++, kind, title: text, detail: detail?.trim() || undefined, action };
    const same = (other: Toast) => other.kind === toast.kind && other.title === toast.title && other.detail === toast.detail;
    if (this.current && same(this.current)) {
      this.left = TOAST_SECONDS[kind];
      return;
    }
    if (this.waiting.some(same)) return;
    if (this.current) this.waiting.push(toast);
    else this.present(toast);
  }

  /// `elapsed` seconds went by; while `paused` (the pointer is on the toast) it stays.
  advance(elapsed: number, paused: boolean) {
    if (!this.current || paused) return;
    this.left -= elapsed;
    if (this.left <= 0) this.dismiss();
  }

  /// Runs the current toast's button once, then closes it.
  act() {
    const action = this.current?.action;
    this.dismiss();
    action?.run();
  }

  /// Closes the current toast and shows the next one waiting.
  dismiss() {
    const next = this.waiting.shift() ?? null;
    if (next) this.present(next);
    else {
      this.current = null;
      this.changed(null);
    }
  }

  private present(toast: Toast) {
    this.current = toast;
    // A toast with a button stays a little longer, so there is time to reach it.
    this.left = TOAST_SECONDS[toast.kind] + (toast.action ? 3 : 0);
    this.changed(toast);
  }
}
