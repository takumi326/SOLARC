function copyValueFrom(el) {
  if (!el) return ""
  if (el.tagName === "TEXTAREA" || el.tagName === "INPUT") return el.value || ""
  return el.textContent || ""
}

function showCopyToast(message) {
  var container = document.getElementById("js-copy-toast")
  var notice = document.getElementById("js-copy-toast-message")
  if (!container || !notice) return

  notice.textContent = message
  container.classList.remove("hidden")
  container.classList.add("flex")

  window.clearTimeout(showCopyToast._hideTimer)
  window.clearTimeout(showCopyToast._fadeTimer)

  window.requestAnimationFrame(function () {
    container.classList.remove("opacity-0")
    container.classList.add("opacity-100")
  })

  showCopyToast._hideTimer = window.setTimeout(function () {
    container.classList.remove("opacity-100")
    container.classList.add("opacity-0")
    showCopyToast._fadeTimer = window.setTimeout(function () {
      container.classList.add("hidden")
      container.classList.remove("flex")
    }, 200)
  }, 2500)
}

document.addEventListener("click", function (event) {
  var button = event.target.closest("[data-copy-text], [data-copy-source]")
  if (!button) return

  event.preventDefault()
  var text = button.getAttribute("data-copy-text") || ""
  var source = button.getAttribute("data-copy-source")
  if (source) {
    var sourceEl = document.querySelector(source)
    if (sourceEl) text = copyValueFrom(sourceEl)
  }
  var fillSource = button.getAttribute("data-copy-fill-source")
  var fillToken = button.getAttribute("data-copy-fill-token")
  if (fillSource && fillToken && text.indexOf(fillToken) !== -1) {
    var fillEl = document.querySelector(fillSource)
    if (fillEl) {
      var fill = copyValueFrom(fillEl)
      if (fillEl.getAttribute("type") === "application/json") {
        try { fill = JSON.parse(fillEl.textContent) } catch (e) { fill = copyValueFrom(fillEl) }
      }
      text = text.replace(fillToken, function () { return fill })
    }
  }
  var suffixSource = button.getAttribute("data-copy-suffix-source")
  if (suffixSource) {
    var suffixEl = document.querySelector(suffixSource)
    if (suffixEl) {
      var suffix = copyValueFrom(suffixEl)
      if (suffix) text = text.replace(/\s+$/, "") + "\n\n" + suffix.replace(/^\s+/, "")
    }
  }
  if (!text) return

  navigator.clipboard.writeText(text).then(function () {
    var label = button.getAttribute("data-copy-label")
    if (label) {
      button.textContent = label + "済"
      window.setTimeout(function () {
        button.textContent = label
      }, 2000)
    }

    var flashMessage = button.getAttribute("data-copy-flash")
    if (!flashMessage) {
      flashMessage = label ? label + "しました" : "クリップボードにコピーしました"
    }
    showCopyToast(flashMessage)
  }).catch(function () {
    window.alert("クリップボードへのコピーに失敗しました")
  })
})
