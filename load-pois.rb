#!/usr/bin/env ruby

require 'yaml'

require 'rubygems'
require 'json'
require 'data_mapper'
require 'dm-validations'

poi_file = "york-poi.yaml"

# Read in the database configuration details from the PHP include file
# that will be used to help serve up the POIs.
# This is a bit embarrassing.
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
  property :fullRefresh,         Integer, :default => 1
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
  property :showSmallBiw,        Integer, :default => 1
  property :showSmallBiwOnClick, Integer, :default => 1
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
  property :autoTriggerRange,    Integer
  property :autoTriggerOnly,     Integer, :default => 0
  property :contentType,         String,  :default => "application/vnd.layar.internal"
  property :method,              String   # "GET", "POST"
  property :activityType,        Integer
  property :params,              String
  property :closeBiw,            Integer, :default => 0
  property :showActivity,        Integer, :default => 1
  property :activityMessage,     String
  property :autoTrigger,         Boolean, :required => true, :default => false
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

# http://rubydoc.info/github/datamapper/dm-core/master/DataMapper/Property
# :precision: number of significant digits
# :scale: number of significant digits to the right of the decimal point

# We need to leave all column names alone in the database, to work with a legacy system,
# the one Layer gives in their demo
#
# The DataMapper docs are bad about how to do this. Figured it out from
# http://www.engineyard.com/blog/2011/using-datamapper-and-rails-with-legacy-schemas/
DataMapper.repository(:default).adapter.field_naming_convention = lambda do |property|
  "#{property.name}"
end

DataMapper.auto_migrate!
DataMapper.finalize

DataMapper::Model.raise_on_save_failure = true

 begin
  config = YAML.load_file(poi_file)
rescue Exception => e
  puts e
  exit 1
end

puts "Layers ..."

config['layers'].each do |layer|
  puts "  #{layer['layer']}"
  Layer.create(:id              => layer['id'],
               :layer           => layer['layer'],
               :refreshInterval => layer['refreshInterval'],
               :refreshDistance => layer['refreshDistance'],
               :fullRefresh     => layer['fullRefresh'],
               :showMessage     => layer['showMessage'],
               :biwStyle        => layer['biwStyle'],
              )
end

puts "POIs ..."

if config['pois']
  config['pois'].each do |poi|
    begin
      puts "  #{poi['title']}"
      POI.create(
          :id                  => poi['id'],
          :layerID             => poi['layerID'],
          :title               => poi['title'],
          :description         => poi['description'],
          :footnote            => poi['footnote'],
          :lat                 => poi['lat'],
          :lon                 => poi['lon'],
          :imageURL            => poi['imageURL'],
          :biwStyle            => poi['biwStyle'],
          :alt                 => poi['alt'],
          :doNotIndex          => poi['doNotIndex'],
          :showSmallBiw        => poi['showSmallBiw'],
          :showSmallBiwOnClick => poi['showSmallBiwOnClick'],
          :poiType             => poi['poiType'],
          :iconID              => poi['iconID'],
          :objectID            => poi['objectID'],
          :transformID         => poi['transformID'],
          )
    rescue Exception => e
      puts e
    end
  end
end

puts "POI Actions ..."

if config['poiActions']
  config['poiActions'].each do |poiaction|
    puts "  #{poiaction['label']}"
    begin
      POIAction.create(
                :id               => poiaction['id'],
                :poiID            => poiaction['poiID'],
                :label            => poiaction['label'],
                :uri              => poiaction['uri'],
                :autoTriggerRange => poiaction['autoTriggerRange'],
                :autoTriggerOnly  => poiaction['autoTriggerOnly'],
                :contentType      => poiaction['contentType'],
                :method           => poiaction['method'],
                :activityType     => poiaction['activityType'],
                :params           => poiaction['params'],
                :closeBiw         => poiaction['doNotIndex'],
                :showActivity     => poiaction['showActivity'],
                :activityMessage  => poiaction['activityMessage'],
                :autoTrigger      => poiaction['autoTrigger'],
                )
    rescue Exception => e
      puts e
    end
  end
end

# TO DO Add LayerAction loading here

puts "Icons ..."

if config['icons']
  config['icons'].each do |icon|
    puts "  #{icon['label']}"
    begin
      Icon.create(
           :id               => icon['id'],
           :label            => icon['label'],
           :url              => icon['url'],
           :type             => icon['type'],
           )
    rescue Exception => e
      puts e
    end
  end
end

puts "Objects ..."

if config['objects']
  config['objects'].each do |o|
    puts "  #{o['url']}"
    begin
      LayarObject.create(
                  :id               => o['id'],
                  :url              => o['url'],
                  :reducedURL       => o['reducedURL'],
                  :contentType      => o['contentType'],
                  :size             => o['size'],
                  )
    rescue Exception => e
      puts e
    end
  end
end

puts "Transforms ..."

if config['transforms']
  config['transforms'].each do |t|
    puts "  #{t['id']}"
    begin
      Transform.create(
                :id               => t['id'],
                :rel              => t['rel'],
                :angle            => t['angle'],
                :rotate_x         => t['rotate_x'],
                :rotate_y         => t['rotate_y'],
                :rotate_z         => t['rotate_z'],
                :translate_x      => t['translate_x'],
                :translate_y      => t['translate_y'],
                :translate_z      => t['translate_x'],
                :scale            => t['scale'],
                )
    rescue Exception => e
      puts e
    end
  end
end

