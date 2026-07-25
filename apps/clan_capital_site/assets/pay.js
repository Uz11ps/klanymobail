// Clan Capital — checkout flow via ЮKassa.
// Backend (mobile API) должен реализовать:
//   POST /api/payments/create  { planCode, amount, returnUrl } -> { confirmationUrl, paymentId }
//   GET  /api/payments/:id                                     -> { status, promoCode? }

const API_BASE = window.API_BASE || 'http://31.31.201.32:8782/api';

document.querySelectorAll('.plan .btn').forEach((btn) => {
  btn.addEventListener('click', async () => {
    const planCode = btn.dataset.plan;
    const amount = Number(btn.dataset.amount);
    const originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Перенаправление…';
    try {
      const res = await fetch(`${API_BASE}/payments/create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          planCode,
          amount,
          returnUrl: `${window.location.origin}/pay/success.html`,
        }),
      });
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const data = await res.json();
      if (!data.confirmationUrl) throw new Error('confirmationUrl missing');
      localStorage.setItem('cc_payment_id', data.paymentId || '');
      window.location.href = data.confirmationUrl;
    } catch (err) {
      btn.disabled = false;
      btn.textContent = originalText;
      alert('Не удалось создать платёж: ' + err.message);
    }
  });
});
