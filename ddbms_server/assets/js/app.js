import { Elm } from "../src/Main.elm"
import { Socket } from "phoenix"

const windowSize = {
    width: window.innerWidth,
    height: window.innerHeight
}

var app = Elm.Main.init({
    flags: { window: windowSize },
    node: document.getElementById("elm")
})


const socket = new Socket("/socket", {})
socket.connect()

let channel = socket.channel("live", {})
channel.join()
    .receive("ok", on_join(channel, app))
    .receive("error", resp => { console.log("Unable to join", resp) })

var joined = false

function on_join(channel, app) {
    return (resp) => {
        if (!joined) {
            console.log(app)


            joined = true
            channel.on("update", response => {
                console.log("update")
                app.ports.receivedMessage.send(response["message"])
            })

            app.ports.sendQuery.subscribe(script => {
                channel.push("query", { script: script })
                    .receive("ok", response => {
                        app.ports.receivedMessage.send("Done")
                    })
                    .receive("error", response => {
                        app.ports.receivedMessage.send(response["reason"])
                    })
            })
        }
    }
}