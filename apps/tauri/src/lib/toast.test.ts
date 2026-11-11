import { describe, expect, it } from "vitest";
import { ToastQueue, TOAST_SECONDS } from "./toast";

describe("toasts", () => {
  it("take turns and close by themselves", () => {
    const shown: (string | null)[] = [];
    const queue = new ToastQueue((t) => shown.push(t?.title ?? null));
    queue.show("Opgeslagen", "success");
    queue.show("Push mislukt", "error", "remote rejected");
    expect(queue.current?.title).toBe("Opgeslagen");
    queue.advance(TOAST_SECONDS.success, false);
    expect(queue.current?.title).toBe("Push mislukt");
    expect(queue.current?.detail).toBe("remote rejected");
    queue.advance(TOAST_SECONDS.error, false);
    expect(queue.current).toBeNull();
    expect(shown).toEqual(["Opgeslagen", "Push mislukt", null]);
  });

  it("stay while hovered, and an error stays longer than a confirmation", () => {
    const queue = new ToastQueue();
    queue.show("Fout", "error");
    queue.advance(100, true);
    expect(queue.current?.title).toBe("Fout");
    queue.advance(TOAST_SECONDS.success, false);
    expect(queue.current?.title).toBe("Fout");
    expect(TOAST_SECONDS.error).toBeGreaterThan(TOAST_SECONDS.success);
  });

  it("show the same message once, and skip empty ones", () => {
    const queue = new ToastQueue();
    queue.show("Gekopieerd", "success");
    queue.advance(2, false);
    queue.show("Gekopieerd", "success");
    queue.advance(2, false);
    expect(queue.current?.title).toBe("Gekopieerd");
    queue.show("   ");
    queue.dismiss();
    expect(queue.current).toBeNull();
  });
});

describe("toasts with a button", () => {
  it("run the button once, close, and stay a little longer than a plain toast", () => {
    let undone = 0;
    const queue = new ToastQueue();
    queue.show("Gesprek verwijderd", "info", undefined, { label: "Ongedaan maken", run: () => undone++ });
    queue.advance(TOAST_SECONDS.info, false);
    expect(queue.current?.action?.label).toBe("Ongedaan maken");
    queue.act();
    expect(undone).toBe(1);
    expect(queue.current).toBeNull();
    queue.act();
    expect(undone).toBe(1);
  });
});
