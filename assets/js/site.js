(() => {
  const strings = {
    en: {
      nav_principles: 'Principles',
      nav_release: 'Release',
      nav_changelog: 'Changelog',
      nav_docs: 'Docs',
      view_source: 'View source ↗',
      hero_eyebrow: 'Windows maintenance, with receipts',
      hero_title_1: 'Know what changes.',
      hero_title_2: 'Choose what runs.',
      hero_lead: 'WinTune inspects a Windows PC locally, explains every recommendation, and asks before taking action. Updates are signed and verified before they are installed.',
      download_windows: 'Download for Windows',
      read_docs: 'Read the documentation',
      fact_release: 'Current release',
      fact_platform: 'Platform',
      fact_channel: 'Channel',
      note_local: 'Local-first',
      note_local_sub: 'Checks stay on your PC',
      note_signed: 'Signed update path',
      principles_eyebrow: 'Built for careful maintenance',
      principles_title: 'Useful without being intrusive.',
      p1_title: 'Local first',
      p1_body: 'Diagnostics run on the device. Optional analysis data is shown locally first and only sent after a clear choice.',
      p2_title: 'Actions with context',
      p2_body: 'Every action shows why it is suggested, what it changes, and whether elevation is required.',
      p3_title: 'Verified delivery',
      p3_body: 'The launcher validates HTTPS, a signed manifest, package hash, and every release file before switching versions.',
      release_eyebrow: 'Latest signed build',
      release_body: 'Extract the starter ZIP, then double-click <code>Start-WinTune.cmd</code>. The launcher keeps future updates verified and clearly confirmed.',
      copy_hash: 'Copy',
      copied_hash: 'Copied',
      changed_title: 'What changed',
      telemetry_title: 'Optional analysis data',
      privacy_badge: 'Previewed locally before sending',
      telemetry_sent_title: 'Sent after confirmation',
      telemetry_sent_body: 'App and Windows versions, locale, admin state, device category, RAM and storage buckets, scan outcomes, rule IDs, action or collector status codes, plus a random installation UUID and session UUID.',
      telemetry_blocked_title: 'Never sent',
      telemetry_blocked_body: 'Username, computer name, full file paths, serial numbers, hardware identifiers, raw event messages, process command lines, and raw IP addresses.',
      source_title: 'Source',
      public_repo: 'Public repository ↗',
      docs_eyebrow: 'Documentation',
      docs_title: 'From a first scan to signed releases.',
      docs_body: 'Read the installation notes, security model, API surface, release process, and privacy boundaries.',
      open_docs: 'Open WinTune docs ↗',
      aria_toggle_theme: 'Toggle colour scheme',
      aria_switch_language: 'Switch language',
      toast_download_title: 'Downloading WinTune',
      toast_download_body: 'Preparing the signed starter ZIP.',
      toast_success_title: 'Download ready',
      toast_success_body: 'Thank you for trying WinTune. You can find more small tools and projects on angusu.de.',
      toast_success_link: 'More on angusu.de',
      toast_error_title: 'Download failed',
      toast_server_error: 'The server had a problem. Please try again in a moment.',
      toast_network_error: 'Please check your internet connection and try again.'
    },
    de: {
      nav_principles: 'Prinzipien',
      nav_release: 'Release',
      nav_changelog: 'Changelog',
      nav_docs: 'Docs',
      view_source: 'Source ansehen ↗',
      hero_eyebrow: 'Windows-Wartung mit Belegen',
      hero_title_1: 'Wissen, was sich ändert.',
      hero_title_2: 'Wählen, was läuft.',
      hero_lead: 'WinTune untersucht einen Windows-PC lokal, erklärt jede Empfehlung und fragt vor jeder Aktion nach. Updates werden vor der Installation signiert und geprüft.',
      download_windows: 'Download für Windows',
      read_docs: 'Dokumentation lesen',
      fact_release: 'Aktuelles Release',
      fact_platform: 'Plattform',
      fact_channel: 'Kanal',
      note_local: 'Lokal zuerst',
      note_local_sub: 'Checks bleiben auf deinem PC',
      note_signed: 'Signierter Update-Pfad',
      principles_eyebrow: 'Für vorsichtige Wartung gebaut',
      principles_title: 'Nützlich, ohne aufdringlich zu sein.',
      p1_title: 'Lokal zuerst',
      p1_body: 'Diagnosen laufen auf dem Gerät. Optionale Analysedaten werden lokal gezeigt und nur nach klarer Entscheidung gesendet.',
      p2_title: 'Aktionen mit Kontext',
      p2_body: 'Jede Aktion zeigt, warum sie vorgeschlagen wird, was sie ändert und ob Adminrechte nötig sind.',
      p3_title: 'Verifizierte Auslieferung',
      p3_body: 'Der Launcher prüft HTTPS, ein signiertes Manifest, den Paket-Hash und jede Release-Datei vor dem Versionswechsel.',
      release_eyebrow: 'Aktueller signierter Build',
      release_body: 'Starter-ZIP entpacken, dann <code>Start-WinTune.cmd</code> doppelklicken. Der Launcher hält spätere Updates geprüft und klar bestätigt.',
      copy_hash: 'Kopieren',
      copied_hash: 'Kopiert',
      changed_title: 'Was geändert wurde',
      telemetry_title: 'Optionale Analysedaten',
      privacy_badge: 'Lokal einsehbar vor dem Senden',
      telemetry_sent_title: 'Wird nach Bestätigung gesendet',
      telemetry_sent_body: 'App- und Windows-Versionen, Locale, Adminstatus, Gerätekategorie, RAM- und Speicher-Buckets, Scan-Ergebnisse, Rule-IDs, Statuscodes von Aktionen oder Collectors sowie eine zufällige Installations-UUID und Session-UUID.',
      telemetry_blocked_title: 'Wird nie gesendet',
      telemetry_blocked_body: 'Nutzername, Computername, vollständige Dateipfade, Seriennummern, Hardware-IDs, rohe Eventmeldungen, Prozess-Commandlines und rohe IP-Adressen.',
      source_title: 'Source',
      public_repo: 'Öffentliches Repository ↗',
      docs_eyebrow: 'Dokumentation',
      docs_title: 'Vom ersten Scan bis zu signierten Releases.',
      docs_body: 'Lies Installationshinweise, Sicherheitsmodell, API-Fläche, Release-Prozess und Datenschutzgrenzen.',
      open_docs: 'WinTune-Docs öffnen ↗',
      aria_toggle_theme: 'Farbschema wechseln',
      aria_switch_language: 'Sprache wechseln',
      toast_download_title: 'WinTune wird heruntergeladen',
      toast_download_body: 'Das signierte Starter-ZIP wird vorbereitet.',
      toast_success_title: 'Download bereit',
      toast_success_body: 'Danke, dass du WinTune ausprobierst. Auf angusu.de findest du mehr kleine Tools und Projekte.',
      toast_success_link: 'Mehr auf angusu.de',
      toast_error_title: 'Download fehlgeschlagen',
      toast_server_error: 'Der Server hatte ein Problem. Bitte gleich nochmal versuchen.',
      toast_network_error: 'Bitte Internetverbindung prüfen und nochmal versuchen.'
    }
  };

  const getLang = () => {
    const saved = localStorage.getItem('angusu_de-lang');
    if (saved === 'de' || saved === 'en') return saved;
    return (navigator.language || '').toLowerCase().startsWith('de') ? 'de' : 'en';
  };
  const setLang = (lang) => {
    const dict = strings[lang] || strings.en;
    document.documentElement.lang = lang;
    localStorage.setItem('angusu_de-lang', lang);
    document.querySelectorAll('[data-i18n]').forEach((node) => {
      const value = dict[node.dataset.i18n];
      if (value == null) return;
      if (value.includes('<')) node.innerHTML = value;
      else node.textContent = value;
    });
    document.querySelectorAll('[data-i18n-aria]').forEach((node) => {
      const value = dict[node.dataset.i18nAria];
      if (value != null) node.setAttribute('aria-label', value);
    });
    const langToggle = document.querySelector('#langToggle');
    if (langToggle) langToggle.textContent = lang.toUpperCase();
  };

  const applyTheme = (theme) => {
    const dark = theme === 'dark';
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    localStorage.setItem('angusu_de-theme', theme);
    const tc = document.querySelector('#metaThemeColor');
    if (tc) tc.content = dark ? '#08080f' : '#f6f6fa';
    const cs = document.querySelector('#metaColorScheme');
    if (cs) cs.content = dark ? 'dark' : 'light';
  };

  const toggleTheme = () => {
    const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    const button = document.querySelector('#themeToggle');
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!document.startViewTransition || reduce || !button) {
      applyTheme(next);
      return;
    }
    const rect = button.getBoundingClientRect();
    const x = rect.left + rect.width / 2;
    const y = rect.top + rect.height / 2;
    const radius = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
    const transition = document.startViewTransition(() => applyTheme(next));
    transition.ready.then(() => {
      document.documentElement.animate({
        clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${radius}px at ${x}px ${y}px)`]
      }, { duration: 620, easing: 'ease-in-out', pseudoElement: '::view-transition-new(root)' });
    });
  };

  document.querySelector('#themeToggle')?.addEventListener('click', toggleTheme);
  document.querySelector('#langToggle')?.addEventListener('click', () => {
    setLang((document.documentElement.lang || 'en').startsWith('de') ? 'en' : 'de');
  });
  setLang(getLang());

  document.querySelectorAll('[data-copy]').forEach((button) => button.addEventListener('click', async () => {
    const source = document.querySelector(button.dataset.copy);
    if (!source) return;
    await navigator.clipboard.writeText(source.textContent.trim());
    const label = button.textContent;
    button.textContent = strings[document.documentElement.lang]?.copied_hash || 'Copied';
    window.setTimeout(() => { button.textContent = label; }, 1600);
  }));

  const t = (key) => (strings[document.documentElement.lang] || strings.en)[key] || strings.en[key] || key;
  let toastTimer = 0;
  const getDownloadToast = () => {
    let toast = document.querySelector('#downloadToast');
    if (toast) return toast;
    toast = document.createElement('aside');
    toast.id = 'downloadToast';
    toast.className = 'download-toast';
    toast.setAttribute('role', 'status');
    toast.setAttribute('aria-live', 'polite');
    toast.innerHTML = '<div class="download-toast__top"><div><strong></strong><p></p></div><a href="https://angusu.de/" rel="noopener"></a></div><div class="download-toast__track"><span></span></div>';
    document.body.appendChild(toast);
    return toast;
  };
  const showDownloadToast = ({ state, title, body, progress = 0, link = false }) => {
    const toast = getDownloadToast();
    window.clearTimeout(toastTimer);
    toast.dataset.state = state;
    toast.querySelector('strong').textContent = title;
    toast.querySelector('p').textContent = body;
    const anchor = toast.querySelector('a');
    anchor.textContent = t('toast_success_link');
    anchor.hidden = !link;
    const bar = toast.querySelector('.download-toast__track span');
    bar.style.width = `${Math.max(0, Math.min(100, progress))}%`;
    toast.classList.add('is-visible');
    if (state !== 'loading') {
      toastTimer = window.setTimeout(() => toast.classList.remove('is-visible'), 9000);
    }
  };
  const saveBlob = (blob, filename) => {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename || 'WinTuneAdvisor-Setup.zip';
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 30000);
  };
  const wireDownloadToast = () => {
    const link = document.querySelector('a[href*="/wintune/api/v1/download"]');
    if (!link || !window.fetch || !window.ReadableStream) return;
    link.addEventListener('click', async (event) => {
      event.preventDefault();
      if (link.dataset.downloading === 'true') return;
      link.dataset.downloading = 'true';
      const filename = link.getAttribute('download') || 'WinTuneAdvisor-Setup.zip';
      showDownloadToast({ state: 'loading', title: t('toast_download_title'), body: t('toast_download_body'), progress: 4 });
      try {
        const response = await fetch(link.href, { cache: 'no-store' });
        if (!response.ok) throw new Error(response.status >= 500 ? 'server' : 'network');
        if (!response.body) {
          const blob = await response.blob();
          saveBlob(blob, filename);
          showDownloadToast({ state: 'success', title: t('toast_success_title'), body: t('toast_success_body'), progress: 100, link: true });
          return;
        }
        const total = Number(response.headers.get('content-length')) || 0;
        const reader = response.body.getReader();
        const chunks = [];
        let received = 0;
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
          received += value.length;
          const progress = total > 0 ? Math.round((received / total) * 100) : Math.min(92, 8 + Math.round(received / 2048));
          showDownloadToast({ state: 'loading', title: t('toast_download_title'), body: t('toast_download_body'), progress });
        }
        const blob = new Blob(chunks, { type: response.headers.get('content-type') || 'application/zip' });
        saveBlob(blob, filename);
        showDownloadToast({ state: 'success', title: t('toast_success_title'), body: t('toast_success_body'), progress: 100, link: true });
      } catch (error) {
        const serverProblem = error && error.message === 'server';
        showDownloadToast({
          state: 'error',
          title: t('toast_error_title'),
          body: serverProblem ? t('toast_server_error') : t('toast_network_error'),
          progress: 100
        });
      } finally {
        link.dataset.downloading = 'false';
      }
    });
  };
  wireDownloadToast();

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
