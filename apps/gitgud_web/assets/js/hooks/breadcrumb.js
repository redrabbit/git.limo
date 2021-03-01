export default () => {
  document.querySelectorAll("nav.level .breadcrumb").forEach(breadcrumb => {
    const level = breadcrumb.closest(".level")
    const levelRight = level.querySelector(".level-right")
    let fromIndex = 2
    let ellipsis
    let truncate = levelRight ? levelRight.offsetLeft + levelRight.offsetWidth - level.offsetWidth
                              : breadcrumb.offsetLeft + breadcrumb.offsetWidth - level.offsetWidth
    while(truncate > 1) {
      const items = breadcrumb.querySelectorAll("ul li")
      if(items.length > 2) {
        const item = items[fromIndex]
        if(!ellipsis) {
          const oldWidth = item.offsetWidth
          ellipsis = item.querySelector("a")
          ellipsis.dataset.tooltip = ellipsis.text
          ellipsis.innerHTML = "&hellip;"
          ellipsis.classList.add("tooltip")
          truncate -= oldWidth - item.offsetWidth
          fromIndex += 1
        } else {
          ellipsis.href = item.querySelector("a").href
          ellipsis.dataset.tooltip = `${ellipsis.dataset.tooltip}/${item.querySelector("a").text}`
          truncate -= item.offsetWidth
          item.parentNode.removeChild(item)
        }
      } else {
        break
      }
    }
  })
}
