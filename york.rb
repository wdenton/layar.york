#!/usr/bin/env ruby

require 'cgi'

require 'rubygems'
require 'json'
require 'data_mapper'
require 'dm-validations'

# Read in the database configuration details from the PHP include file
# that will be used to help serve up the POIs.
# This feels a bit dirty.
db = Hash.new
File.open("york-config.inc.php", "r").each_line do |line|
  results = line.match(/define\('(\w*)', '(.*)'\);/)
  if results
    db[results[1]] = results[2] # db["DBUSER"] = "username"
  end
end

DataMapper.setup(:default, "mysql://" + db["DBUSER"] + ":" + db["DBPASS"] + "@" + db["DBHOST"] + "/" + db["DBDATA"])

DataMapper::Property::String.length(255)


class Layer
  include DataMapper::Resource
  storage_names[:default] = 'Layer'
  property :id,                  String,  :key => true
  property :layer,               String,  :required => true
  property :refreshInterval,     Integer, :default => 300
  property :refreshDistance,     Integer, :default => 100
  property :fullRefresh,         Boolean, :default => true
  property :showMessage,         String
  property :biwStyle,            String
end

class POI
  include DataMapper::Resource
  storage_names[:default] = 'POI'
  property :id,                  String,  :key => true
  property :layerID,             Integer, :required => true
  property :title,               String,  :required => true
  property :description,         String
  property :footnote,            String
  property :lat,                 Float,   :required => true
  property :lon,                 Float,   :required => true
  property :imageURL,            String
  property :biwStyle,            String,  :default => "classic"
  property :alt,                 Float,   :default => 0
  property :doNotIndex,          Integer, :default => 0
  property :showSmallBiw,        Boolean, :default => true
  property :showBiwOnClick,      Boolean, :default => true
  property :poiType,             String,  :required => true, :default => "geo"
  property :iconID,              Integer
  property :objectID,            Integer
  property :transformID,         Integer

  def distance(latitude, longitude)

    # poi.distance(latitude, longitude) = distance from the POI to that point

    # Taken from https://github.com/almartin/Ruby-Haversine/blob/master/haversine.rb
    # https://github.com/almartin/Ruby-Haversine
    earthRadius = 6371 # Earth's radius in km

    # convert degrees to radians
    def convDegRad(value)
      unless value.nil? or value == 0
        value = (value/180) * Math::PI
      end
      return value
    end

    # latitude = 100
    # longitude = 40

    deltaLat = (self.lat - latitude)
    deltaLon = (self.lon - longitude)
    deltaLat = convDegRad(deltaLat)
    deltaLon = convDegRad(deltaLon)

    # Calculate square of half the chord length between latitude and longitude
    a = Math.sin(deltaLat/2) * Math.sin(deltaLat/2) +
      Math.cos((self.lat/180 * Math::PI)) * Math.cos((latitude/180 * Math::PI)) *
      Math.sin(deltaLon/2) * Math.sin(deltaLon/2);
    # Calculate the angular distance in radians
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))

    distance = earthRadius * c * 1000 # meters
    return distance
  end
end

class POIAction
  include DataMapper::Resource
  storage_names[:default] = 'POIAction'
  property :id,                  Integer, :key => true
  property :poiID,               String,  :required => true
  property :label,               String,  :required => true
  property :uri,                 String,  :required => true
  property :contentType,         String,  :default => "application/vnd.layar.internal"
  property :method,              String,  :default => "GET"   # "GET", "POST"
  property :activityType,        Integer, :default => 1
  property :params,              String
  property :closeBiw,            Boolean, :default => false
  property :showActivity,        Boolean, :default => false
  property :activityMessage,     String
  property :autoTrigger,         Boolean, :required => true, :default => false
  property :autoTriggerRange,    Integer
  property :autoTriggerOnly,     Boolean, :default => false
end

class LayerAction
  include DataMapper::Resource
  storage_names[:default] = "LayerAction"
  property :id,                  Integer, :key => true
  property :layerID,             String,  :required => true
  property :label,               String,  :required => true
  property :uri,                 String,  :required => true
  property :contentType,         String,  :default => "application/vnd.layar.internal"
  property :method,              String   # "GET", "POST"
  property :activityType,        Integer
  property :params,              String
  property :closeBiw,            Integer, :default => 0
  property :showActivity,        Integer, :default => 1
  property :activityMessage,     String
end

class Icon
  include DataMapper::Resource
  storage_names[:default] = "Icon"
  property :id,                  Integer, :key => true
  property :label,               String
  property :url,                 String,  :required => true
  property :type,                Integer, :default => 0
end

class LayarObject
  include DataMapper::Resource
  storage_names[:default] = "Object"
  property :id,                  Integer, :key => true
  property :url,                 String,  :required => true
  property :reducedURL,          String,  :required => true
  property :contentType,         String,  :required => true
  property :size,                Float,   :required => true
end

class Transform
  include DataMapper::Resource
  storage_names[:default] = "Transform"
  property :id,                  Integer, :key => true
  property :rel,                 Integer, :default => 0
  property :angle,               Decimal, :precision => 5,  :scale => 2, :default => 0.00
  property :rotate_x,            Decimal, :precision => 2,  :scale => 1, :default => 0.0
  property :rotate_y,            Decimal, :precision => 2,  :scale => 1, :default => 0.0
  property :rotate_z,            Decimal, :precision => 2,  :scale => 1, :default => 1.0
  property :translate_x,         Decimal, :precision => 5,  :scale => 1, :default => 0.0
  property :translate_y,         Decimal, :precision => 5,  :scale => 1, :default => 0.0
  property :translate_z,         Decimal, :precision => 5,  :scale => 1, :default => 0.0
  property :scale,               Decimal, :precision => 12, :scale => 2, :default => 1
end

DataMapper.repository(:default).adapter.field_naming_convention = lambda do |property|
  "#{property.name}"
end

# URL being called looks like this:
#
# http://www.miskatonic.org/ar/york.php?
# lang=en
# & countryCode=CA
# & userId=6f85d06929d160a7c8a3cc1ab4b54b87db99f74b
# & lon=-79.503089
# & version=6.0
# & radius=1500
# & lat=43.7731464
# & layerName=yorkuniversitytoronto
# & accuracy=100

# Mandatory params passed in:
# userId
# layerName
# version
# lat
# lon
# countryCode
# lang
# action
#
# Optional but important (what if no radius is specified?)
# radius

cgi = CGI.new
params = cgi.params

layer = Layer.first(:layer => params["layerName"])

# TODO: Catch error if no layer

all_pois = POI.all(:layerID => layer["id"])
# all_pois = POI.all

# TODO: Handle case of no POIs with proper error message

latitude = params["lat"][0].to_f
longitude = params["lon"][0].to_f

radius = params["radius"][0].to_i || 500

hotspots = []

all_pois.each do |poi|
  next if poi.distance(latitude, longitude) > radius
  # puts poi["title"]
  hotspot = Hash.new
  hotspot["id"] = poi["id"]
  hotspot["text"] = {
    "title" => poi["title"],
    "description" => poi["description"],
    "footnote" => poi["footnote"]
  }
  hotspot["imageURL"] = poi["imageURL"]
  hotspot["anchor"] = {"geolocation" => {"lat" => poi["lat"], "lon" => poi["lon"]}}
  hotspot["biwStyle"] = poi["biwStyle"]
  hotspot["showSmallBiw"] = poi["showSmallBiw"]
  hotspot["showBiwOnClick"] = poi["showBiwOnClick"]

  # Associate any actions
  actions = POIAction.all(:poiID => poi["id"])
  if actions.length > 0 # ??
    # puts poi["title"]
    hotspot["actions"] = []
    actions.each do |action|
      # puts action["uri"]
      # puts action["label"]
      hotspot["actions"] << {
        "uri" => action["uri"],
        "label" => action["label"],
        "contentType" => action["contentType"],
        "activityType" => action["activityType"],
        "method" => action["method"]
      }
    end
  end

  # Is there an icon?
  if poi["iconID"]
    icon = Icon.get(poi["iconID"])
    hotspot["icon"] = {
      "url" => icon["url"],
      "type" => icon["type"]
    }
  end

  hotspots << hotspot
end

errorcode = 0 # Can be 20-29 if there is an error ... use this.
errorstring = ""

response = {
  "layer" => layer["layer"],
  "biwStyle" => layer["biwStyle"],
  "showMessage" => layer["showMessage"],
  "refreshDistance" => layer["refreshDistance"],
  "refreshInterval" => layer["refreshInterval"],
  "hotspots" => hotspots,
  "errorcode" => errorcode,
  "errorstring" => errorstring,
}
# TODO add layer actions

if ! params["radius"]
  response["radius"] = radius
end

puts response.to_json
