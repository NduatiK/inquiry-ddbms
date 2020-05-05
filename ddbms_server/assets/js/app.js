import {Elm} from "../src/Main.elm"

const windowSize = {
    width: window.innerWidth,
    height: window.innerHeight
}

var app = Elm.Main.init({
    flags: { window: windowSize },
    node: document.getElementById("elm")
})
