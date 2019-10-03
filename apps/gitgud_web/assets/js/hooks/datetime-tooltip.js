import moment from "moment"

export default () => {
  const datetimes = document.querySelectorAll("time[class=tooltip]")
  setInterval(() => {
    datetimes.forEach(datetime => {
      datetime.textContent = moment.utc(new Date(datetime.getAttribute("datetime"))).fromNow()
    })
  }, 3000)
}
