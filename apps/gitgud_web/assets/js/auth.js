export const token = (() => {
  let meta = document.querySelector("meta[name='token']")
  return meta ? meta.content : null
})()
