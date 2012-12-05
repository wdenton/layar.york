#!/usr/bin/env ruby

require 'yaml'
require 'cgi'

require 'rubygems'
require 'json'

url_file = "york-urls.yaml"

# TODO: Load this in live (or accept as option if local?)
# http://www.yorku.ca/web/maps/kml/all_placemarks.js

# Emergency phones: http://www.yorku.ca/web/maps/kml/Emergency-Phones.kml
# Wheeltrans: http://www.yorku.ca/web/maps/kml/Wheeltrans.kml
# GoSafe: http://www.yorku.ca/web/maps/kml/go-safe.kmz
# Shuttle: http://www.yorku.ca/web/maps/kml/Shuttle.kml
# YRT: http://www.yorku.ca/web/maps/kml/yrt-transit.kml
# Pickup: http://www.yorku.ca/web/maps/kml/Pickup.kmz

json = JSON.parse(File.open("all_placemarks.js").read)

begin
  urls = YAML.load_file(url_file)
rescue Exception => e
  puts e
  exit 1
end

pois = []
actions = []
icons = []

layers = [{
    "layer" => "York University",
    "id" => 1,
    "refreshInterval" => 300,
    "refreshDistance" =>  100,
    "fullRefresh" => 1,
    "showMessage" => "",
    "biwStyle" => "classic"
  }
]

json.each do |placemark|
  if placemark["category"].any? {|c| c.match(/transit/i)} # Ignore anything in a Transit category (for now)
    next
  end
  poi = Hash.new
  poi["id"] = placemark["ID"]
  poi["title"] = CGI.unescapeHTML(placemark["title"])
  STDERR.puts poi["title"]
  #  puts poi["title"]
  # The content field is a chunk of HTML. We want to just use what's inside the <address> tags, but not the first such chunk because
  # it's the name of the place, and then we want to trim the length of the text to 140 characters.  A bit ugly.
  content = placemark["content"].match(/<address>(.*)<.+address>/) # Get all content from first <address> to last <\\/address>
  if content.nil?
    poi["description"] = ""
  else
    # Split, ignore the first chunk, join all the rest, and trim
    poi["description"] = content[1].split("</address><address>").slice(1..-1).join("; ").slice(0, 135)
  end
  poi["footnote"] = ""
  poi["lat"] = placemark["latitude"][0].to_s
  poi["lon"] = placemark["longitude"][0].to_s

  grabbedimage = placemark["content"].match(/src=\"(.*jpg)/)
  # The icon is what floats in space.  Use the same grabbed image if we can.
  icon = Hash.new
  if grabbedimage.nil?
    poi["imageURL"] = "http://www.yorku.ca/web/css/yeb11yorklogo.gif" # Standard York logo
    icon["url"] = "http://www.miskatonic.org/ar/york-ciw-110x110.png" # Squared, can be improved
  else
    poi["imageURL"] = grabbedimage[1]
    icon["url"] = poi["imageURL"]
  end
  STDERR.puts "  icon: #{icon["url"]}"
  icon["id"] = icons.length + 1
  poi["iconID"] = icon["id"]
  icon["label"] = poi["title"]
  icon["type"] = 0
  icons << icon

  poi["biwStyle"] = "classic"
  poi["alt"] = 0
  poi["doNotIndex"] = 0
  poi["showSmallBiw"] = 1
  poi["showSmallBiwOnClick"] = 1
  poi["poiType"] = "geo"
  poi["layerID"] = 1

  action = Hash.new
  url = urls.fetch(poi["title"], nil)
  if ! url.nil? # There is a URL for this location
    STDERR.puts "  URL: #{url["url"]}"
    action["id"] = actions.length + 1;
    action["poiID"] = poi["id"]
    action["label"] = url["label"]
    action["uri"] = url["url"]
    action["contentType"] = "application/vnd.layar.internal"
    action["method"] = "GET"
    action["activityType"] = 1
    action["params"] = ""
    action["closeBiw"] = 0
    action["showActivity"] = 1
    action["activityMessage"] = ""
    action["autoTrigger"] = false
    actions << action
  end

  pois << poi
  # placemark.delete("content")
  #  placemark.each do |k, v|
  #    puts k
  #  end
  # print placemark["title"].chomp, " (", placemark["latitude"], ", ", placemark["longitude"], ")\n"
  # puts placemark.to_yaml
end

yaml = {
  "layers" => layers,
  "pois" => pois,
  "poiActions" => actions,
  "icons" => icons,
}

puts yaml.to_yaml

