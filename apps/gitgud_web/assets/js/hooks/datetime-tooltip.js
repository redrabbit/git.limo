import moment from "moment"

function renderDateTimes(dateTimes) {
  dateTimes.forEach(dateTime => {
    dateTime.textContent = moment.utc(new Date(dateTime.getAttribute("datetime"))).fromNow()
  })
}
export default () => {
  const dateTimes = document.querySelectorAll("time[class=tooltip]")
  renderDateTimes(dateTimes)
  setInterval(() => renderDateTimes(dateTimes), 3000)
}
