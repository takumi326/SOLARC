(function () {
  function drawer() {
    return document.getElementById("mobile-nav-drawer")
  }

  function overlay() {
    return document.getElementById("mobile-nav-overlay")
  }

  function openNav() {
    var el = drawer()
    var veil = overlay()
    if (!el || !veil) return

    el.classList.remove("-translate-x-full")
    veil.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  function closeNav() {
    var el = drawer()
    var veil = overlay()
    if (!el || !veil) return

    el.classList.add("-translate-x-full")
    veil.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  document.addEventListener("click", function (event) {
    if (event.target.closest("#mobile-nav-open")) {
      event.preventDefault()
      openNav()
      return
    }

    if (event.target.closest("#mobile-nav-close") || event.target.closest("#mobile-nav-overlay")) {
      closeNav()
      return
    }

    if (event.target.closest("#mobile-nav-drawer a")) {
      closeNav()
    }
  })

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") closeNav()
  })
})()
