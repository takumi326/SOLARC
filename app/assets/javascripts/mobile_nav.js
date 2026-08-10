(function () {
  function drawer() {
    return document.getElementById("mobile-nav-drawer")
  }

  function overlay() {
    return document.getElementById("mobile-nav-overlay")
  }

  function isMobileNav() {
    return window.matchMedia("(max-width: 767px)").matches
  }

  function openNav() {
    if (!isMobileNav()) return

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

  function bindMobileNav() {
    closeNav()
  }

  document.addEventListener("DOMContentLoaded", bindMobileNav)
  document.addEventListener("turbo:load", bindMobileNav)

  window.addEventListener("resize", function () {
    if (!isMobileNav()) closeNav()
  })

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
