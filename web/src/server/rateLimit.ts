type AttemptWindow = {
  count: number;
  resetAt: number;
};

const windows = new Map<string, AttemptWindow>();
const windowMs = 15 * 60 * 1000;
const maxAttempts = 5;

export function canAttempt(key: string, now = Date.now()): boolean {
  const current = windows.get(key);
  if (!current || current.resetAt <= now) {
    windows.set(key, { count: 0, resetAt: now + windowMs });
    return true;
  }
  return current.count < maxAttempts;
}

export function recordFailedAttempt(key: string, now = Date.now()): void {
  const current = windows.get(key);
  if (!current || current.resetAt <= now) {
    windows.set(key, { count: 1, resetAt: now + windowMs });
    return;
  }
  current.count += 1;
}

export function clearAttempts(key: string): void {
  windows.delete(key);
}
