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
  var button = event.target.closest("[data-copy-text]")
  if (!button) return

  event.preventDefault()
  var text = button.getAttribute("data-copy-text")
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
