(function () {
  function applyFilter(input) {
    var selector = input.getAttribute("data-list-filter")
    if (!selector) return
    var table = document.querySelector(selector)
    if (!table) return

    var q = input.value.trim().toLowerCase()
    var rows = table.querySelectorAll("tbody tr[data-search]")
    var visible = 0
    rows.forEach(function (row) {
      var hit = !q || (row.getAttribute("data-search") || "").toLowerCase().indexOf(q) !== -1
      row.classList.toggle("hidden", !hit)
      if (hit) visible += 1
    })

    var empty = document.querySelector(input.getAttribute("data-list-empty") || "")
    if (empty) empty.classList.toggle("hidden", visible !== 0 || rows.length === 0)
  }

  document.addEventListener("input", function (event) {
    var input = event.target.closest("[data-list-filter]")
    if (input) applyFilter(input)
  })
})()
