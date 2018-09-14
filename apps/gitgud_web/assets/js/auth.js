export const token = (() => {
  let meta = document.getElementsByName("token")
  if(meta.length > 0) return meta[0].getAttribute("content")
})()
