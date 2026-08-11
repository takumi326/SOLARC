(function () {
  function root() {
    return document.getElementById("daily-routine-root")
  }

  function loadRoutine(url, push) {
    var current = root()
    if (!current) return

    fetch(url, {
      headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
      credentials: "same-origin"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("failed")
        return response.text()
      })
      .then(function (html) {
        var doc = new DOMParser().parseFromString(html, "text/html")
        var next = doc.getElementById("daily-routine-root")
        if (!next || !root()) return
        root().replaceWith(next)
        if (push) history.pushState({ dailyRoutine: true }, "", url)
      })
      .catch(function () {
        window.location.href = url
      })
  }

  document.addEventListener("click", function (event) {
    var link = event.target.closest("a[data-routine-link]")
    if (!link || !root()) return
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()
    loadRoutine(link.href, true)
  })

  window.addEventListener("popstate", function () {
    if (!root()) return
    loadRoutine(window.location.href, false)
  })
})()
