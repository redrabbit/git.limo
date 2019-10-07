import Pickr from "@simonwep/pickr"

import "@simonwep/pickr/dist/themes/nano.min.css"

export default () => {
  document.querySelectorAll("table.issue-label-table").forEach(table => {
    table.querySelectorAll("tbody tr").forEach(row => {
      let label = row.querySelector(".issue-label")
      row.querySelectorAll(".color-picker").forEach(colorPicker => {
        let button = colorPicker.querySelector(".pickr")
        let nameInput = colorPicker.querySelector("input")
        let colorInput = button.nextElementSibling

        let pickr = Pickr.create({
          el: button,
          theme: 'nano',
          useAsButton: true,
          default: colorInput.value,
          components: {
            preview: true,
            hue: true,
          }
        })

        button.classList.remove("is-hidden")
        colorInput.style.display = "none"
        nameInput.addEventListener("input", event => label.innerHTML = event.target.value)

        pickr.on("change", (color, instance) => {
          const threshold = 130
          color = color.toHEXA().toString().toLowerCase()
          const hRed = parseInt(color.substring(1,3), 16)
          const hGreen = parseInt(color.substring(3,5), 16)
          const hBlue = parseInt(color.substring(5,7), 16)
          const cBrightness = ((hRed * 299) + (hGreen * 587) + (hBlue * 114)) / 1000
          colorInput.value = color
          label.style.backgroundColor = color
          button.innerHTML = color
          button.style.backgroundColor = color
          if(cBrightness > threshold) {
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
      })

      row.querySelector("a.delete").addEventListener("click", event => {
        document.getElementById(event.target.dataset.labelId).remove()
        table.deleteRow(row.rowIndex)
      })
    })
  })
}
