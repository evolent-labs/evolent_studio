export function toClipboard(text: string) {
  const area = document.createElement('textarea');
  area.value = text;
  area.style.cssText = 'position:fixed;left:-9999px;top:0';
  document.body.appendChild(area);
  area.select();
  document.execCommand('copy');
  area.remove();
}
