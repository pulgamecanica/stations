require "csv"
require "luhnacy"
require "set"
require "stringex"
require "tzinfo"
require_relative "lib/constants"

# This script generates a text file "data.txt" for my program cpp_on_rails

puts "Starting data scraping!"

SCALING_FACTOR = 100  # Adjust this value as needed, big factors separate more the nodes
OUT_NODES_POSITIONS = "positions.txt"
OUT_NODES = "nodes.txt"
STATIONS = CSV.read("stations.csv", **Constants::CSV_PARAMETERS)
TOTAL_STATIONS = STATIONS.size

stations_unique = Hash.new(0)
country_count = Hash.new(0)

# Cute progress bar
def progress_bar(current, total, title, bar_length = 40)
  percent = (current / total.to_f) * 100
  filled_length = (bar_length * current / total).round
  bar = '█' * filled_length + ' ' * (bar_length - filled_length)
  print "\r#{title} |#{bar}| #{percent.round(2)}% Complete"
end


# Helper function to format node names (remove spaces or replace with underscores)
def format_node_name(name)
  name.strip.gsub(/\s+/, '_') # Replace spaces with underscores
end

# Sort the CSV rows by country before populating the hash
STATIONS.sort_by { |row| row["country"] }.each_with_index do |row, index|
  # Update progress bar
  progress_bar(index + 1, TOTAL_STATIONS, "Processing Stations")
  # Only add station to the hash if it's not already present (ensure uniqueness)
  node_name = format_node_name(row["name"])  # Format the node name
  unless stations_unique.key?(node_name)
    latitude = row["latitude"].to_f * SCALING_FACTOR  # Scale latitude
    longitude = row["longitude"].to_f * SCALING_FACTOR  # Scale longitude
    country = row["country"]    
    stations_unique[node_name] = { country: country, latitude: latitude, longitude: longitude }
    # Increment the station count for the country only for unique stations
    country_count[country] += 1
  end
end


# Writing to files with a progress bar
puts

TOTAL_UNIQUE_STATIONS = stations_unique.size # Total unique nodes to write

File.open(OUT_NODES, 'w') do |file|
  stations_unique.each_with_index do |(name, station), index|
    progress_bar(index + 1, TOTAL_UNIQUE_STATIONS, "Writing Nodes")
    file.puts("Node #{name}")
  end
end

# Writing to files with a progress bar
puts

File.open(OUT_NODES_POSITIONS, 'w') do |file|
  stations_unique.each_with_index do |(name, station), index|
    progress_bar(index + 1, TOTAL_UNIQUE_STATIONS, "Writing Nodes Positions")
    file.puts("#{name} #{station[:latitude]} #{station[:longitude]}")
  end
end

# Print the number of unique stations by each country
puts "\nUnique station counts by country:"
country_count.each do |country, count|
  puts "#{country}: #{count} station(s)"
end

puts "Done, check out #{OUT_NODES} & #{OUT_NODES_POSITIONS}"
puts "\tFinished totaling #{TOTAL_UNIQUE_STATIONS} stations"
puts "\tFinished totaling #{country_count.size} countries"