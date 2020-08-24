import { Elm } from "../src/Main.elm"
import { Socket } from "phoenix"

// Init the SPA with the window's size
var app = Elm.Main.init({
    flags: {},
    node: document.getElementById("elm")
})


// Connect to the backend with a socket
const socket = new Socket("/socket", {})
socket.connect()

// Use the live channel for all communication
let channel = socket.channel("live", {})
channel.join()
.receive("ok", on_join(channel, app))
.receive("error", resp => { console.log("Unable to join", resp) })

var joined = false

function on_join(channel, app) {
    return (resp) => {
        // Setup on join but only do it once
        // No need for multiple subscriptions
        if (!joined) {
            joined = true
            
            
            // When a query result is received from the backend,
            // pass it to elm
            channel.on("update", response => {
                console.log("update")
                app.ports.receivedMessage.send(response["message"])
            })

            // When a query submitted to the backend, 
            // check and report whether the query was successfully 
            // received and if not, why?
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