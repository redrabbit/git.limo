export const token = (() => {
  let meta = document.querySelector("meta[name='token']")
  return meta ? meta.content : null
})()

export const currentUser = (() => {
  if(token) {
    return {
      login: document.getElementById("viewer-login").innerText,
      avatarUrl: document.getElementById("viewer-avatar").src.split("?")[0]
    }
  }
})()
