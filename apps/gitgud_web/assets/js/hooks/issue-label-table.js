import Pickr from "@simonwep/pickr"

import "@simonwep/pickr/dist/themes/nano.min.css"

export default () => {
  document.querySelectorAll("table.issue-label-table").forEach(table => {
    let changeSet = new Set([])
    let newLabels = []
    let pickrList = []
    let submitButton = table.querySelector("button[type=submit]")
    let resetButton = table.querySelector("button[type=reset]")
    let addButton = document.getElementById("add-label")
    let nextLabelIndex = Array.from(table.querySelectorAll("input[id^=repo_issue_labels_][id$=_id]")).reduce((acc, input) => Math.max(acc, parseInt(input.id.split("_")[3])) + 1, 0)

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

      nameInput.addEventListener("input", event => {
        if(event.target.value != event.target.defaultValue) {
          changeSet.add(event.target.id)
        } else {
          changeSet.delete(event.target.id)
        }
        submitButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
        resetButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
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
        submitButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
        resetButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
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
          input.disabled = true
          changeSet.add(labelId)
          submitButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
          resetButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
          event.currentTarget.setAttribute("disabled", "")
          pickr.disable()
          button.setAttribute("disabled", "")
          row.cells[0].querySelector("button").disabled = true
          row.cells[1].querySelectorAll("input").forEach(input => input.disabled = true)
        }
      })
    })

    addButton.addEventListener("click", event => {
      let row = table.tBodies[0].insertRow(-1)
      let col = row.insertCell(0)
      let label = document.createElement("button")
      label.classList.add("button")
      label.classList.add("issue-label")
      label.classList.add("is-active")
      label.classList.add("has-text-dark")
      label.style.backgroundColor = "#dddddd"
      label.innerHTML = "new label"
      col.appendChild(label)

      col = row.insertCell(1)
      let nameInput = document.createElement("input")
      nameInput.classList.add("input")
      nameInput.classList.add("is-small")
      nameInput.id = `repo_issue_labels_${nextLabelIndex}_name`
      nameInput.name = `repo[issue_labels][${nextLabelIndex}][name]`
      nameInput.value = "new label"
      nameInput.type = "text"
      nameInput.required = true
      nameInput.addEventListener("input", event => {
        submitButton.disabled = false
        resetButton.disabled = false
        label.innerHTML = event.target.value
      })

      let colorButton = document.createElement("a")
      colorButton.classList.add("button")
      colorButton.classList.add("pickr")
      colorButton.classList.add("has-text-dark")
      colorButton.style.backgroundColor = "#dddddd"
      colorButton.innerHTML = "#dddddd"

      let colorInput = document.createElement("input")
      colorInput.id = `repo_issue_labels_${nextLabelIndex}_color`
      colorInput.name = `repo[issue_labels][${nextLabelIndex}][color]`
      colorInput.type = "hidden"
      colorInput.value = "dddddd"
      colorInput.required = true

      let colorInputControl = document.createElement("div")
      colorInputControl.classList.add("control")
      colorInputControl.appendChild(colorButton)
      colorInputControl.appendChild(colorInput)

      let nameInputControl = document.createElement("div")
      nameInputControl.classList.add("control")
      nameInputControl.appendChild(nameInput)

      let colorPicker = document.createElement("div")
      colorPicker.classList.add("field")
      colorPicker.classList.add("color-picker")
      colorPicker.classList.add("has-addons")
      colorPicker.appendChild(nameInputControl)
      colorPicker.appendChild(colorInputControl)

      let inputControl = document.createElement("div")
      inputControl.classList.add("control")
      inputControl.appendChild(colorPicker)

      let icon = document.createElement("i")
      icon.classList.add("fa")
      icon.classList.add("fa-times")

      let iconContainer = document.createElement("span")
      iconContainer.classList.add("icon")
      iconContainer.appendChild(icon)

      let removeLink = document.createElement("a")
      removeLink.classList.add("button")
      removeLink.classList.add("is-white")
      removeLink.classList.add("is-inverted")
      removeLink.classList.add("is-link")
      removeLink.classList.add("is-small")
      removeLink.dataset.labelIndex = nextLabelIndex
      removeLink.appendChild(iconContainer)
      removeLink.addEventListener("click", event => {
        table.deleteRow(row.rowIndex)
        newLabels = newLabels.filter(index => index != event.currentTarget.dataset.labelIndex)
        submitButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
        resetButton.disabled = (changeSet.size == 0 && newLabels.length == 0)
      })

      let removeControl = document.createElement("div")
      removeControl.classList.add("control")
      removeControl.appendChild(removeLink)

      let fieldGroup = document.createElement("div")
      fieldGroup.classList.add("field")
      fieldGroup.classList.add("is-grouped")
      fieldGroup.classList.add("is-pulled-right")
      fieldGroup.appendChild(inputControl)
      fieldGroup.appendChild(removeControl)

      col.appendChild(fieldGroup)

      let pickr = Pickr.create({
        el: colorButton,
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

      pickr.on("change", color => {
        color = color.toHEXA().toString().toLowerCase()
        const threshold = 137
        const hRed = parseInt(color.substring(1,3), 16)
        const hGreen = parseInt(color.substring(3,5), 16)
        const hBlue = parseInt(color.substring(5,7), 16)
        const brightness = ((hRed * 299) + (hGreen * 587) + (hBlue * 114)) / 1000
        colorInput.value = color.substring(1)
        label.style.backgroundColor = color
        colorButton.innerHTML = color
        colorButton.style.backgroundColor = color
        if(brightness > threshold) {
          label.classList.add("has-text-dark")
          label.classList.remove("has-text-light")
          colorButton.classList.add("has-text-dark")
          colorButton.classList.remove("has-text-light")
        } else {
          label.classList.add("has-text-light")
          label.classList.remove("has-text-dark")
          colorButton.classList.add("has-text-light")
          colorButton.classList.remove("has-text-dark")
        }
      })

      newLabels.push(nextLabelIndex++)
      submitButton.disabled = false
      resetButton.disabled = false
    })

    resetButton.addEventListener("click", event => {
      event.preventDefault()
      changeSet.forEach(id => {
        let input = document.getElementById(id)
        input.value = input.dataset.defaultValue || input.defaultValue
        input.disabled = false
        if(id.endsWith("_id")) {
          let deleteButton = table.querySelector(`a[data-label-id="${id}"]`)
          deleteButton.removeAttribute("disabled")
          let row = deleteButton.closest("tr")
          row.cells[0].querySelector("button").disabled = false
          row.cells[1].querySelectorAll("input").forEach(input => input.disabled = false)
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
      newLabels.forEach(index => {
        table.deleteRow(table.querySelector(`a[data-label-index="${index}"]`).closest("tr").rowIndex)
      })
      changeSet.clear()
      newLabels = []
      submitButton.disabled = true
      resetButton.disabled = true
    })
  })
}
