(function () {
  function formatYen(amount) {
    const prefix = amount < 0 ? "-¥" : "¥";
    return prefix + Math.abs(amount).toLocaleString("ja-JP");
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function selectedOptionText(select) {
    if (!select || select.selectedIndex < 0) return "";
    return select.options[select.selectedIndex].text;
  }

  function paymentMethodByCardId() {
    const map = {};
    document.querySelectorAll("[data-import-card-payment-method]").forEach((select) => {
      const cardId = select.dataset.cardId;
      if (!cardId) return;
      map[cardId] = select.value ? selectedOptionText(select) : "未選択";
    });
    return map;
  }

  function refreshCandidatePaymentLabels() {
    const paymentNames = paymentMethodByCardId();
    document.querySelectorAll("tr[data-card-id] [data-import-payment-label]").forEach((label) => {
      const tr = label.closest("tr[data-card-id]");
      if (!tr) return;
      const name = paymentNames[tr.dataset.cardId] || "未選択";
      label.textContent = name;
      label.setAttribute("title", name);
    });
  }

  function collectRows() {
    const root = document.getElementById("import-final-preview");
    if (!root) return [];

    let existing = [];
    try {
      existing = JSON.parse(root.dataset.existingRows || "[]");
    } catch (_error) {
      existing = [];
    }

    const paymentNames = paymentMethodByCardId();
    const rows = existing.map((row) => ({
      kind: "existing",
      label: row.label,
      cardName: row.cardName || "未設定",
      categoryPath: row.categoryPath,
      amount: Number(row.amount || 0),
      memo: row.memo || ""
    }));

    document.querySelectorAll("[data-import-candidate]").forEach((tr) => {
      const checkbox = tr.querySelector('input[type="checkbox"][name="line_numbers[]"]');
      if (!checkbox || !checkbox.checked) return;

      const categorySelect = tr.querySelector("[data-import-category]");
      const memoInput = tr.querySelector('input[type="text"]');
      const paymentName = paymentNames[tr.dataset.cardId];
      if (!paymentName || paymentName === "未選択") return;

      rows.push({
        kind: "new",
        label: "これから保存（No." + tr.dataset.lineNumber + "）",
        cardName: paymentName,
        categoryPath: selectedOptionText(categorySelect),
        amount: Number(tr.dataset.amount || 0),
        memo: memoInput ? memoInput.value.trim() : ""
      });
    });

    return rows;
  }

  function renderCardGroup(cardName, rows) {
    const amount = rows.reduce((sum, row) => sum + row.amount, 0);
    const body = rows
      .slice()
      .sort((a, b) => {
        const category = a.categoryPath.localeCompare(b.categoryPath, "ja");
        if (category !== 0) return category;
        if (a.amount !== b.amount) return a.amount - b.amount;
        return a.label.localeCompare(b.label, "ja");
      })
      .map(
        (row) =>
          "<tr class=\"" + (row.kind === "new" ? "bg-white/60" : "") + "\">" +
          "<td class=\"whitespace-nowrap px-2 py-1.5 text-xs text-emerald-800\">" + escapeHtml(row.label) + "</td>" +
          "<td class=\"px-2 py-1.5\">" + escapeHtml(row.categoryPath) + "</td>" +
          "<td class=\"px-2 py-1.5 text-right whitespace-nowrap tabular-nums\">" + formatYen(row.amount) + "</td>" +
          "<td class=\"max-w-[14rem] px-2 py-1.5\"><span class=\"block truncate\" title=\"" + escapeHtml(row.memo) + "\">" +
          escapeHtml(row.memo || "—") +
          "</span></td>" +
          "</tr>"
      )
      .join("");

    return (
      "<div class=\"overflow-x-auto rounded border border-emerald-100 bg-white/70\">" +
      "<div class=\"flex flex-wrap items-center justify-between gap-2 border-b border-emerald-100 bg-emerald-50/80 px-2 py-1.5\">" +
      "<span class=\"text-xs font-medium text-emerald-900\">" + escapeHtml(cardName) + "</span>" +
      "<span class=\"text-xs tabular-nums text-emerald-800\">" + rows.length + " 件 / " + formatYen(amount) + "</span>" +
      "</div>" +
      "<table class=\"w-full min-w-[48rem] divide-y divide-emerald-100 text-sm\">" +
      "<thead class=\"text-left text-xs text-emerald-800\"><tr>" +
      "<th class=\"whitespace-nowrap px-2 py-1.5\">区分</th>" +
      "<th class=\"min-w-[12rem] px-2 py-1.5\">カテゴリ</th>" +
      "<th class=\"whitespace-nowrap px-2 py-1.5 text-right\">金額</th>" +
      "<th class=\"min-w-[10rem] px-2 py-1.5\">メモ</th>" +
      "</tr></thead>" +
      "<tbody class=\"divide-y divide-emerald-100/80\">" + body + "</tbody>" +
      "</table>" +
      "</div>"
    );
  }

  function refreshFinalPreview() {
    const root = document.getElementById("import-final-preview");
    const container = document.getElementById("import-final-preview-by-card");
    const summary = document.getElementById("import-final-preview-summary");
    if (!root || !container || !summary) return;

    const rows = collectRows();
    const groups = {};
    rows.forEach((row) => {
      const key = row.cardName || "未設定";
      if (!groups[key]) groups[key] = [];
      groups[key].push(row);
    });

    const cardNames = Object.keys(groups).sort((a, b) => a.localeCompare(b, "ja"));
    container.innerHTML = cardNames.map((name) => renderCardGroup(name, groups[name])).join("");

    const totalAmount = rows.reduce((sum, row) => sum + row.amount, 0);
    summary.textContent = rows.length + " 件 / " + formatYen(totalAmount);
  }

  function refreshAll() {
    refreshCandidatePaymentLabels();
    refreshFinalPreview();
  }

  const DRAFT_SAVE_DELAY_MS = 400;
  let draftSaveTimer = null;
  let draftSaveInFlight = null;
  let draftSaveQueued = false;

  function csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute("content") : "";
  }

  function previewForm() {
    return document.querySelector("form[data-import-preview-form]");
  }

  function scheduleDraftSave() {
    const form = previewForm();
    if (!form || !form.dataset.draftUrl) return;

    clearTimeout(draftSaveTimer);
    draftSaveTimer = setTimeout(() => {
      draftSaveTimer = null;
      saveDraft(form);
    }, DRAFT_SAVE_DELAY_MS);
  }

  function saveDraft(form, options = {}) {
    const keepalive = options.keepalive === true;
    if (!keepalive && draftSaveInFlight) {
      draftSaveQueued = true;
      return draftSaveInFlight;
    }

    const body = new FormData(form);
    body.delete("raw_json");
    const request = fetch(form.dataset.draftUrl, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": csrfToken(),
        "X-Requested-With": "XMLHttpRequest"
      },
      body: body,
      credentials: "same-origin",
      keepalive: keepalive
    })
      .then((response) => {
        if (!response.ok && response.status !== 410) {
          console.warn("finance import draft save failed", response.status);
        }
      })
      .catch((error) => {
        console.warn("finance import draft save failed", error);
      });

    if (keepalive) return request;

    draftSaveInFlight = request.finally(() => {
      draftSaveInFlight = null;
      if (draftSaveQueued) {
        draftSaveQueued = false;
        saveDraft(form);
      }
    });

    return draftSaveInFlight;
  }

  function flushDraftSave() {
    const form = previewForm();
    if (!form || !form.dataset.draftUrl) return;

    clearTimeout(draftSaveTimer);
    draftSaveTimer = null;
    saveDraft(form, { keepalive: true });
  }

  function bindPreviewSync() {
    const form = previewForm() || document.querySelector("[data-import-card-payment-method]")?.closest("form");
    if (!form || form.dataset.importPreviewBound === "1") return;
    form.dataset.importPreviewBound = "1";

    form.addEventListener("change", (event) => {
      if (event.target.matches("[data-import-card-payment-method]")) {
        refreshAll();
        scheduleDraftSave();
        return;
      }
      if (!event.target.closest("[data-import-candidate]")) return;
      if (event.target.matches('input[type="checkbox"]') || event.target.matches("select")) {
        refreshFinalPreview();
        scheduleDraftSave();
      }
    });

    form.addEventListener("input", (event) => {
      if (event.target.closest("[data-import-candidate]") && event.target.matches('input[type="text"]')) {
        refreshFinalPreview();
        scheduleDraftSave();
      }
    });

    form.addEventListener("submit", () => {
      clearTimeout(draftSaveTimer);
      draftSaveTimer = null;
    });

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "hidden") flushDraftSave();
    });
    window.addEventListener("pagehide", flushDraftSave);

    refreshAll();
  }

  document.addEventListener("DOMContentLoaded", bindPreviewSync);
  document.addEventListener("turbo:load", bindPreviewSync);
})();
