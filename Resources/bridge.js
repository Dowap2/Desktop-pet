// chatgpt.com 페이지에 주입. window.__usagiSend(text): 입력 -> 전송 -> 답변을 Swift로 전달
(function () {
  if (window.__usagiSend) return;
  const post = o => webkit.messageHandlers.usagi.postMessage(o);
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const msgs = () => document.querySelectorAll('[data-markdown-text-style="assistant-message"], [data-message-author-role="assistant"]');

  const esc = t => t.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  // 숨긴 창은 포커스가 없어 execCommand가 안 먹을 수 있으므로 DOM에 직접 넣고 input 이벤트로 알린다
  function setText(box, text) {
    if (box.tagName === 'TEXTAREA') {
      Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(box, text);
    } else {
      box.focus();
      document.execCommand('selectAll', false, null);
      document.execCommand('insertText', false, text);
      if (box.innerText.trim() !== text.trim())
        box.innerHTML = text.split('\n').map(l => '<p>' + esc(l) + '</p>').join('');
    }
    box.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
  }

  const run = async function (text) {
    const box = document.querySelector('#prompt-textarea, .ProseMirror[contenteditable=true], textarea');
    if (!box) return post({ type: 'error', text: '입력칸을 못 찾음. 웹 화면에서 로그인했는지 확인하세요.' });
    const before = msgs().length;
    setText(box, text);

    let btn = null;
    const find = () => document.querySelector('button[data-testid="send-button"]:not([disabled]), button[aria-label*="전송"]:not([disabled]), button[aria-label*="Send"]:not([disabled]), button[type="submit"]:not([disabled])');
    for (let i = 0; i < 20 && !(btn = find()); i++) await sleep(100);
    if (!btn) return post({ type: 'error', text: '전송 버튼을 못 찾음. 입력칸 내용: "' + box.innerText.slice(0, 30) + '" | 버튼들: ' + [...document.querySelectorAll('button')].map(b => (b.getAttribute('aria-label')||'') + '/' + (b.dataset.testid||'') + (b.disabled?'(disabled)':'')).filter(x => x !== '/').slice(-12).join(', ') });
    btn.click();

    let last = '', idle = 0;
    const t0 = Date.now();
    while (Date.now() - t0 < 180000) {
      await sleep(400);
      const m = msgs(), el = m.length > before ? m[m.length - 1] : null;
      const t = el ? el.innerText : '';
      const busy = !!document.querySelector('button[data-testid="stop-button"], button[aria-label*="중지"], button[aria-label*="Stop"]');
      if (!el && !busy && Date.now() - t0 > 15000) return post({ type: 'error', text: '답변이 시작되지 않음 (화면 구조가 바뀌었을 수 있음)' });
      if (t !== last) { last = t; post({ type: 'delta', text: t }); idle = 0; }
      else if (!busy && t && ++idle >= 3) break;   // 답변이 멈추고 중지 버튼도 없으면 완료
    }
    post({ type: 'done' });
  };
  window.__usagiSend = t => { run(t).catch(e => post({ type: 'error', text: 'JS 예외: ' + e })); };   // Promise를 반환하면 evaluateJavaScript가 오류로 처리함
})();
