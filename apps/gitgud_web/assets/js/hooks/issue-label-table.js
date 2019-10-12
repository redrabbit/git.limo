import Pickr from "@simonwep/pickr"

import "@simonwep/pickr/dist/themes/nano.min.css"

export default () => {
  document.querySelectorAll("table.issue-label-table").forEach(table => {
    let changeSet = new Set([])
    let pickrList = []
    let submitButton = table.querySelector("button[type=submit]")
    let resetButton = table.querySelector("button[type=reset]")
    resetButton.addEventListener("click", event => {
      event.preventDefault()
      changeSet.forEach(id => {
        let input = document.getElementById(id)
        if(input.type == "hidden") {
          input.value = input.dataset.defaultValue
        } else {
          input.value = input.defaultValue
        }
        if(id.endsWith("_id")) {
          let deleteButton = table.querySelector(`a[data-label-id=${id}]`)
          deleteButton.removeAttribute("disabled")
          let row = deleteButton.closest("tr")
          row.cells[0].querySelector("button").disabled = false
          row.cells[1].querySelector("input").disabled = false
          row.cells[1].querySelector(".pickr").removeAttribute("disabled")
          let pickr = pickrList[row.rowIndex]
          pickr.enable()
        } else if(id.endsWith("_name")) {
          let row = input.closest("tr")
          row.cells[0].querySelector("button").innerHTML = input.value
        } else if(id.endsWith("_color")) {
          let row = input.closest("tr")
          let pickr = pickrList[row.rowIndex]
          pickr.setColor("#" + input.value)
          pickr._emit("change", pickr._color)
        }
      })
      submitButton.disabled = true
      resetButton.disabled = true
    })
    table.querySelectorAll("tbody tr").forEach(row => {
      let label = row.querySelector(".issue-label")
      let colorPicker = row.querySelector(".color-picker")
      let button = colorPicker.querySelector(".pickr")
      let nameInput = colorPicker.querySelector("input")
      let colorInput = button.nextElementSibling
      colorInput.dataset.defaultValue = colorInput.value

      let pickr = Pickr.create({
        el: button,
        theme: 'nano',
        useAsButton: true,
        default: colorInput.value,
        components: {
          preview: true,
          hue: true,
          interaction: {
            input: true
          }
        },
      })

      pickrList.push(pickr)

      colorInput.style.display = "none"
      nameInput.addEventListener("input", event => {
        if(event.target.value != event.target.defaultValue) {
          changeSet.add(event.target.id)
        } else {
          changeSet.delete(event.target.id)
        }
        submitButton.disabled = (changeSet.size == 0)
        resetButton.disabled = (changeSet.size == 0)
        label.innerHTML = event.target.value
      })

      pickr.on("change", color => {
        color = color.toHEXA().toString().toLowerCase()
        const threshold = 137
        const hRed = parseInt(color.substring(1,3), 16)
        const hGreen = parseInt(color.substring(3,5), 16)
        const hBlue = parseInt(color.substring(5,7), 16)
        const brightness = ((hRed * 299) + (hGreen * 587) + (hBlue * 114)) / 1000
        colorInput.value = color.substring(1)
        if(colorInput.value != colorInput.dataset.defaultValue) {
          changeSet.add(colorInput.id)
        } else {
          changeSet.delete(colorInput.id)
        }
        submitButton.disabled = (changeSet.size == 0)
        resetButton.disabled = (changeSet.size == 0)
        label.style.backgroundColor = color
        button.innerHTML = color
        button.style.backgroundColor = color
        if(brightness > threshold) {
          label.classList.add("has-text-dark")
          label.classList.remove("has-text-light")
          button.classList.add("has-text-dark")
          button.classList.remove("has-text-light")
        } else {
          label.classList.add("has-text-light")
          label.classList.remove("has-text-dark")
          button.classList.add("has-text-light")
          button.classList.remove("has-text-dark")
        }
      })

      row.querySelector("a[data-label-id]").addEventListener("click", event => {
        const labelId = event.currentTarget.dataset.labelId
        let input = document.getElementById(labelId)
        if(input) {
          input.dataset.defaultValue = input.value
          input.value = null
          changeSet.add(labelId)
          submitButton.disabled = (changeSet.size == 0)
          resetButton.disabled = (changeSet.size == 0)
          event.currentTarget.setAttribute("disabled", "")
          pickr.disable()
          button.setAttribute("disabled", "")
          row.cells[0].querySelector("button").disabled = true
          row.cells[1].querySelector("input").disabled = true
        }
      })
    })
  })
}
