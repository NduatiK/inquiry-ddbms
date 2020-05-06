port module Ports exposing (..)


port receivedMessage : (String -> msg) -> Sub msg


port sendQuery : String -> Cmd msg
