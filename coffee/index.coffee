# open up a namespace
window.app = {}
app.data = {}

# some data by the backend
app.data.owner_point = [52.5219763,13.45313770000007]
app.data.owner_address = "Matternstraße 14, 10249 Berlin, Germany"
app.data.pet_radius = 1 # km
app.data.pet_okay = "I´m fine. My Name is Emil my home is not far from here"
app.data.pet_missed = "I’m Lost, please get me home or call my owner! My name is {{ name }} and i need your help."

# helper methods
if (typeof(Number.prototype.toRad) == "undefined")
  Number.prototype.toRad = () ->
    return this * Math.PI / 180;

# get the current location from the browser
app.getCurrentLocation = (success, fail) ->
  # return a deferred
  deferred = $.Deferred()
  # check if the browser features a geolocation api
  if navigator.geolocation
    # request the location from the browser
    navigator.geolocation.getCurrentPosition(deferred.resolve, deferred.reject)
  # return the deferred
  deferred.promise()

# get the address from this position
app.reverseGeoCode = (position) ->
  url = "http://nominatim.openstreetmap.org/reverse?format=json&lat="
  $.ajax(url: url + position.coords.latitude + "&lon=" + position.coords.longitude)

# append the adress to the dom
app.appendAddressToDom = (result) ->
  $("body").append("<div class='debug'><p>Erkannte Adresse: "+result.address.road+" "+result.address.house_number+" "+result.address.postcode+" "+result.address.city+" "+result.address.city_district+" "+result.address.country+" "+result.address.continent+"</p></div>")

# build the link we need for the check map button
app.buildMapRouteLink = (rgv, destResult) ->
  # return a deferred
  deferred = $.Deferred()
  # create the url
  start = escape(rgv.address.road+" "+rgv.address.house_number+", "+rgv.address.postcode+" "+rgv.address.city+" "+rgv.address.country)
  destination = escape(destResult)

  iOS = false
  if(iOS)
    url = "http://maps.apple.com/?saddr="+start+"&daddr="+destination
  else
    url = "http://maps.google.com/maps?saddr="+app.data.current_point.coords.latitude+","+app.data.current_point.coords.longitude+"&daddr="+app.data.owner_point[0]+","+app.data.owner_point[1]+'#Intent;action=android.intent.action.VIEW;package=com.google.android.apps.maps;end'

  # resolve the promise
  deferred.resolve(url)
  # return the deferred
  deferred.promise()

# bring the link to the dom button
app.updateMapRouteLinkButton = (url) ->
  $('#map a.btn').attr("href",url).fadeIn('slow')

# everything our map needs
app.mapInit = () ->
  # load the map
  app.data.map = L.mapbox.map("map", "polarity.map-kicnfk3l")
  app.data.map.dragging.disable()
  app.data.map.touchZoom.disable()
  app.data.map.doubleClickZoom.disable()
  app.data.map.scrollWheelZoom.disable()

# everything our map needs
app.addMarkerHome = (posArr) ->
  marker = L.marker(posArr, {icon: L.mapbox.marker.icon({'marker-color': 'CC0033'})});
  marker.addTo(app.data.map)

# calculate the distance between two points
app.calculateDistance = (point1, point2) ->
  console.log(point1,point2)
  lat1 = point1[0]
  lon1 = point1[1]
  lat2 = point2[0]
  lon2 = point2[1]
  R = 6371; # earth radius in km
  dLat = (lat2-lat1).toRad()
  dLon = (lon2-lon1).toRad()
  lat1 = lat1.toRad()
  lat2 = lat2.toRad()
  a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(lat1) * Math.cos(lat2) 
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  d = R * c

# change the text  
app.catStatus = (status, distance) ->
  if status == "good"
    $(".catstatus p").text(app.data.pet_okay).append(" ("+distance.toFixed(2)+" km)")
    $(".catbrief").removeClass "lost"
  else
    $(".catstatus p").text(app.data.pet_missed).append(" ("+distance.toFixed(2)+" km)")
    $(".catbrief").addClass "lost"

  return

# jQuery on DomReady
# start the app :)
$ ->
  # make the map ready
  app.mapInit()

  # get location from the browser
  app.getCurrentLocation() 
    # set the map to the current browser location
    .done((position) -> app.data.map.setView [position.coords.latitude, position.coords.longitude], 16)
    .done((position) -> app.addMarkerHome [position.coords.latitude, position.coords.longitude])
    .done((position) -> app.addMarkerHome app.data.owner_point)
    .done((position) -> 
          distance = app.calculateDistance app.data.owner_point, [position.coords.latitude, position.coords.longitude]
          app.data.current_point = position # remember current location
          if(distance < app.data.pet_radius)
            app.catStatus "good", distance
          else
            app.catStatus "missing", distance
    )
    # lookup the position and get an adress from openStreetMap
    .then((position) -> app.reverseGeoCode(position) )
    # bring the adress to the dom (debug)
    .done((result) -> app.appendAddressToDom result)
    # build a url out of our adress data
    .then((address) -> app.buildMapRouteLink(address, "") )
    # update the dom with the created link
    .done((url) -> app.updateMapRouteLinkButton url )