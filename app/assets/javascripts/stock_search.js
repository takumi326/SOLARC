(function () {
  var debounceTimer = null
  var selectedIndex = 0
  var items = []

  function root() {
    return document.getElementById("stock-search")
  }

  function inputEl() {
    return document.getElementById("stock-search-input")
  }

  function resultsEl() {
    return document.getElementById("stock-search-results")
  }

  function emptyEl() {
    return document.getElementById("stock-search-empty")
  }

  function isOpen() {
    var el = root()
    return !!(el && el.style.display === "flex")
  }

  function openSearch() {
    var el = root()
    var input = inputEl()
    if (!el || !input || isOpen()) return

    input.value = ""
    items = []
    selectedIndex = 0
    render([])
    el.style.display = "flex"
    document.body.style.overflow = "hidden"
    input.focus()
  }

  function closeSearch() {
    var el = root()
    if (!el) return
    el.style.display = "none"
    document.body.style.overflow = ""
  }

  function render(rows) {
    var list = resultsEl()
    var empty = emptyEl()
    if (!list || !empty) return

    items = rows
    if (selectedIndex >= items.length) selectedIndex = 0
    list.innerHTML = ""
    list.style.padding = "0"

    if (!inputEl().value.trim()) {
      empty.classList.add("hidden")
      return
    }

    if (rows.length === 0) {
      empty.classList.remove("hidden")
      return
    }

    empty.classList.add("hidden")
    list.style.padding = "0 12px 16px"
    rows.forEach(function (row, index) {
      var li = document.createElement("li")
      var a = document.createElement("a")
      a.href = row.url
      a.className = "flex items-center gap-2 rounded-lg px-3 py-2.5 text-sm hover:bg-slate-50"
      if (index === selectedIndex) a.className += " bg-indigo-50"
      a.innerHTML = '<span class="font-mono">' + escapeHtml(row.code) + '</span><span class="font-medium">' + escapeHtml(row.name) + "</span>"
      li.appendChild(a)
      list.appendChild(li)
    })
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }

  function lookup(q) {
    var el = root()
    if (!el) return
    var url = el.getAttribute("data-lookup-url") + "?q=" + encodeURIComponent(q)
    fetch(url, { headers: { Accept: "application/json" } })
      .then(function (res) { return res.json() })
      .then(function (rows) {
        if (inputEl().value.trim() !== q) return
        render(rows)
      })
      .catch(function () { render([]) })
  }

  function goSelected() {
    if (!items.length) return
    var row = items[selectedIndex]
    if (row && row.url) window.location.href = row.url
  }

  document.addEventListener("keydown", function (event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      if (!root()) return
      event.preventDefault()
      if (isOpen()) closeSearch()
      else openSearch()
      return
    }

    if (!isOpen()) return

    if (event.key === "Escape") {
      event.preventDefault()
      closeSearch()
      return
    }

    if (event.key === "ArrowDown") {
      event.preventDefault()
      if (!items.length) return
      selectedIndex = (selectedIndex + 1) % items.length
      render(items)
      return
    }

    if (event.key === "ArrowUp") {
      event.preventDefault()
      if (!items.length) return
      selectedIndex = (selectedIndex - 1 + items.length) % items.length
      render(items)
      return
    }

    if (event.key === "Enter") {
      event.preventDefault()
      goSelected()
    }
  })

  document.addEventListener("input", function (event) {
    if (event.target.id !== "stock-search-input") return
    var q = event.target.value.trim()
    clearTimeout(debounceTimer)
    if (!q) {
      render([])
      return
    }
    debounceTimer = setTimeout(function () { lookup(q) }, 120)
  })

  document.addEventListener("click", function (event) {
    var opener = event.target.closest("[data-stock-search-open]")
    if (opener) {
      event.preventDefault()
      openSearch()
      return
    }
    if (event.target.id === "stock-search-close") {
      event.preventDefault()
      closeSearch()
      return
    }
    if (event.target.id === "stock-search") closeSearch()
  })
})()
