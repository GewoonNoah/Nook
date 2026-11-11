type Key = Pick<KeyboardEvent, "key" | "ctrlKey" | "metaKey" | "altKey" | "shiftKey" | "repeat" | "isComposing" | "defaultPrevented">;
type Context = { paletteOpen: boolean; modalOpen: boolean; editing: boolean; chat: boolean };
type Shortcut = "palette" | "sidebar" | "new" | "settings" | "stop" | "search" | "go-chat" | "go-agents" | "go-workspace" | "go-settings";

/// Ctrl+1 … Ctrl+4 jump straight to a page, in the order of the rail.
const PAGES: Record<string, Shortcut> = { "1": "go-chat", "2": "go-agents", "3": "go-workspace", "4": "go-settings" };

export function shellShortcut(e: Key, context: Context): Shortcut | null {
  if (e.defaultPrevented || e.repeat || e.isComposing || e.altKey || e.shiftKey || !(e.ctrlKey || e.metaKey)) return null;
  if (context.modalOpen && !context.paletteOpen) return null;
  const key = e.key.toLowerCase();
  if (key === "k") return "palette";
  if (context.paletteOpen) return null;
  if (key === "b" && context.chat && !context.editing) return "sidebar";
  if (key === "n") return "new";
  if (key === ",") return "settings";
  if (key === ".") return "stop";
  if (key === "f") return "search";
  if (PAGES[key]) return PAGES[key];
  return null;
}
