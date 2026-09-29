import type { ServerEventMessage } from '../types.js';

export function connectEventStream(
  url: string,
  eventIds: readonly string[],
  onMessage: (message: ServerEventMessage) => void
): () => void {
  let source: EventSource | null = null;
  let attempt = 0;
  let stopped = false;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  function handleNamedEvent(eventId: string) {
    return (event: MessageEvent) => {
      try {
        const parsed = JSON.parse(event.data) as { payload: unknown; contract_version: number };
        onMessage({ id: event.lastEventId, event: eventId, data: parsed.payload, contract_version: parsed.contract_version });
      } catch {
        return;
      }
    };
  }

  function connect(): void {
    if (stopped) return;
    source = new EventSource(url);
    source.onopen = () => {
      attempt = 0;
    };
    for (const eventId of eventIds) {
      source.addEventListener(eventId, handleNamedEvent(eventId));
    }
    source.onerror = () => {
      source?.close();
      if (stopped) return;
      const delay = Math.random() * Math.min(30000, 1000 * 2 ** attempt);
      attempt += 1;
      reconnectTimer = setTimeout(connect, delay);
    };
  }

  connect();

  return () => {
    stopped = true;
    if (reconnectTimer) clearTimeout(reconnectTimer);
    source?.close();
  };
}
