import {token} from "./auth"
import factory from "./react-factory"
import env from "./relay-environment"
import socket from "./socket"

[...document.getElementsByClassName("message")].forEach(flash => {
  flash.querySelector("button.delete").addEventListener("click", event => {
    flash.remove();
  })
})

document.addEventListener("DOMContentLoaded", factory)
