(function () {
  var VISIBLE_MS = 4000

  function dismiss(toast) {
    if (toast.dataset.dismissing) return
    toast.dataset.dismissing = "1"
    toast.style.opacity = "0"
    window.setTimeout(function () {
      var container = toast.parentElement
      toast.remove()
      if (container && !container.querySelector(".js-flash-toast")) container.remove()
    }, 220)
  }

  function init() {
    var toasts = document.querySelectorAll(".js-flash-toast")
    Array.prototype.forEach.call(toasts, function (toast) {
      if (toast.dataset.timerSet) return
      toast.dataset.timerSet = "1"
      window.setTimeout(function () {
        dismiss(toast)
      }, VISIBLE_MS)
    })
  }

  document.addEventListener("click", function (event) {
    var toast = event.target.closest(".js-flash-toast")
    if (toast) dismiss(toast)
  })

  document.addEventListener("DOMContentLoaded", init)
  document.addEventListener("turbo:load", init)
})()
