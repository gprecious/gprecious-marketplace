export function emitJson(data: unknown): void {
  console.log(JSON.stringify(data, null, 2));
}

export function emitError(message: string, extras: Record<string, unknown> = {}): void {
  console.error(JSON.stringify({ error: message, ...extras }));
}
