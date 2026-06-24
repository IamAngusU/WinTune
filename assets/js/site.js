(() => {
  document.querySelectorAll('[data-copy]').forEach((button) => button.addEventListener('click', async () => {
    const source = document.querySelector(button.dataset.copy);
    if (!source) return;
    await navigator.clipboard.writeText(source.textContent.trim());
    const label = button.textContent;
    button.textContent = 'Copied';
    window.setTimeout(() => { button.textContent = label; }, 1600);
  }));

  const image = document.querySelector('#productImage');
  if (!image) return;
  image.addEventListener('load', () => {
    const canvas = document.createElement('canvas');
    const context = canvas.getContext('2d', { willReadFrequently: true });
    canvas.width = image.naturalWidth; canvas.height = image.naturalHeight;
    context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height); const { data } = pixels;
    const seen = new Uint8Array(canvas.width * canvas.height); const queue = new Int32Array(seen.length); let head = 0; let tail = 0;
    const add = (x, y) => { if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) return; const i = y * canvas.width + x; if (seen[i]) return; const p = i * 4; const min = Math.min(data[p], data[p + 1], data[p + 2]); const max = Math.max(data[p], data[p + 1], data[p + 2]); if (data[p + 3] === 0 || (min >= 245 && max - min <= 28)) { seen[i] = 1; queue[tail++] = i; } };
    for (let x = 0; x < canvas.width; x++) { add(x, 0); add(x, canvas.height - 1); }
    for (let y = 0; y < canvas.height; y++) { add(0, y); add(canvas.width - 1, y); }
    while (head < tail) { const i = queue[head++]; const x = i % canvas.width; const y = Math.floor(i / canvas.width); add(x + 1, y); add(x - 1, y); add(x, y + 1); add(x, y - 1); }
    seen.forEach((marked, i) => { if (marked) data[i * 4 + 3] = 0; }); context.putImageData(pixels, 0, 0); image.src = canvas.toDataURL('image/png');
  }, { once: true });
})();
