port module Main exposing (Model, Msg(..), init, main, update, view)

import Browser
import Html exposing (Html, button, div, h1, p, text)
import Html.Events exposing (onClick)
import Json.Decode
import Json.Decode.Pipeline
import Json.Encode


port signIn : () -> Cmd msg


port signInInfo : (Json.Encode.Value -> msg) -> Sub msg


port loggedOutUser : (() -> msg) -> Sub msg


port signInError : (() -> msg) -> Sub msg


port signOut : () -> Cmd msg


port saveCard : Json.Encode.Value -> Cmd msg


port saveCardError : (() -> msg) -> Sub msg


port receiveCards : (Json.Encode.Value -> msg) -> Sub msg


port receiveCardsError : (() -> msg) -> Sub msg



---- MODEL ----


type alias UserData =
    { email : String
    , uid : String
    , name : String
    }


type User
    = Unknown
    | LoggedOut
    | LoginError
    | LoggedIn UserData


type Cards
    = GetCardsFailed
    | SaveCardFailed
    | CardsList (List String)


type alias Model =
    { user : User
    , inputContent : String
    , cards : Cards
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { user = Unknown
      , cards = CardsList []
      , inputContent = ""
      }
    , Cmd.none
    )



---- UPDATE ----


type Msg
    = LogIn
    | LogOut
    | LoggedInData (Result Json.Decode.Error UserData)
    | LoggedInError
    | SaveCard -- TODO: add userId parameter
    | SaveCardError
    | InputChanged String
    | CardsReceived (Result Json.Decode.Error (List String))
    | CardsReceivedError


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LogIn ->
            ( model, signIn () )

        LogOut ->
            ( { model | user = LoggedOut }, signOut () )

        LoggedInData (Ok userData) ->
            ( { model | user = LoggedIn userData }, Cmd.none )

        LoggedInData (Err _) ->
            ( { model | user = LoginError }, Cmd.none )

        LoggedInError ->
            ( { model | user = LoginError }, Cmd.none )

        SaveCard ->
            ( model, saveCard <| messageEncoder model )

        SaveCardError ->
            ( { model | cards = SaveCardFailed }, Cmd.none )

        InputChanged value ->
            ( { model | inputContent = value }, Cmd.none )

        CardsReceived (Ok cards) ->
            ( { model | cards = CardsList cards }, Cmd.none )

        CardsReceived (Err _) ->
            ( { model | cards = GetCardsFailed }, Cmd.none )

        CardsReceivedError ->
            ( { model | cards = GetCardsFailed }, Cmd.none )


messageEncoder : Model -> Json.Encode.Value
messageEncoder model =
    Json.Encode.object
        [ ( "content", Json.Encode.string model.inputContent )
        , ( "uid"
          , case model.user of
                LoggedIn userData ->
                    Json.Encode.string userData.uid

                _ ->
                    Json.Encode.null
          )
        ]


userDataDecoder : Json.Decode.Decoder UserData
userDataDecoder =
    Json.Decode.succeed UserData
        |> Json.Decode.Pipeline.required "email" Json.Decode.string
        |> Json.Decode.Pipeline.required "uid" Json.Decode.string
        |> Json.Decode.Pipeline.optional "name" Json.Decode.string "User"


cardsListDecoder : Json.Decode.Decoder (List String)
cardsListDecoder =
    Json.Decode.succeed identity
        |> Json.Decode.Pipeline.required "cards" (Json.Decode.list Json.Decode.string)


formatUserName : UserData -> String
formatUserName useData =
    useData.name |> String.split " " |> List.head |> Maybe.withDefault "User"



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Kärtchen" ]
        , case model.user of
            Unknown ->
                text "Loading user info..."

            LoggedOut ->
                button [ onClick LogIn ] [ text "Login with Google" ]

            LoginError ->
                text "error obtaining user info"

            LoggedIn userData ->
                div []
                    [ p [] [ text <| "Hello, " ++ formatUserName userData ++ "!" ]
                    , button [ onClick LogOut ] [ text "Logout" ]
                    ]
        ]



---- PROGRAM ----


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ signInInfo <| Json.Decode.decodeValue userDataDecoder >> LoggedInData
        , signInError <| always LoggedInError
        , loggedOutUser <| always LogOut
        , saveCardError <| always SaveCardError
        , receiveCards <| Json.Decode.decodeValue cardsListDecoder >> CardsReceived
        , receiveCardsError <| always CardsReceivedError
        ]


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
