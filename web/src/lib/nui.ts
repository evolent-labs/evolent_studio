declare global {
  function GetParentResourceName(): string;
}

export const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'evolent_studio';

export async function nui<T = any>(name: string, data: unknown = {}, timeout = 10000): Promise<T | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
      signal: controller.signal,
    });
    return (await response.json()) as T;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}
