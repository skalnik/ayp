path = require 'path'

## Set the env so that we don't have to ask again
APP_ROOT = process.env.APP_ROOT = path.resolve(__dirname)

## External configuration
AYP_SECRET = process.env.AYP_SECRET or "That's my secret, they're all my pants."
GA_ID      = process.env.GA_ID

## Load and configure the app
app = require './lib/app'
Comic = require './lib/comic'

app.locals.GA_ID = GA_ID
app.set 'port', (process.env.PORT or 5000)

## Application routes
app.get '/', (request, response) ->
  Comic.latest (err, comic) =>
    # TODO: Better error handling
    return response.status(404).send "I am literally on fire, and I can't find the latest" if err
    response.render 'strip', comic: comic

app.get '/feed.xml', (request, response) ->
  # TODO: Abstract out /archive/* into Comic so I can call it with a callback,
  #       reieve a list and just render the feed view
  Comic.archive 'latest', (err, archive) ->
    return response.status(500).send "Sorry, my programming broke building the feed" if err

    response.set 'Content-Type', 'application/rss+xml'
    return response.render 'feed',
      layout: null
      archive: archive.archive


app.get '/archive/:start?', (request, response) ->
  Comic.archive request.params.start, (err, archive) =>
    return response.redirect("/archive/") if err
    return response.render 'archive', archive

app.get '/random/', (request, response) ->
  Comic.random (err, comic) =>
    # If we fuck up, go back to /
    return response.redirect('/') if err
    return response.redirect("/at/#{comic.time}/")

app.get '/at/:stamp?', (request, response) ->
  failHome = ->
    return response.redirect('/')
  return failHome() if isNaN(stamp = parseInt(request.params.stamp))

  Comic.at stamp, (err, comic) ->
    return failHome() if err
    response.render 'strip', comic: comic

app.post "/new/", (req, res) ->
  res.set 'Content-Type', 'application/json'
  if req.body.secret != AYP_SECRET
    return res.status(401).
      send JSON.stringify error: "You don't know the secret."

  {url, time} = req.body
  return res.status(400).
    send JSON.stringify(error: "Bad format") unless url && time

  (new Comic(url, time)).save (err, comic) ->
    return res.status(500).send(JSON.stringify error: "#{err}") if err
    res.send JSON.stringify {ok: Date.now()}

## Boot sequence
app.listen app.get('port'), ->
  console.log "Your pants running at http://localhost:#{app.get('port')}/"
