require "csv"
require "luhnacy"
require "set"
require "stringex"
require "tzinfo"
require "optparse"  # Required for parsing command-line options
require_relative "lib/constants"

# This script generates a text file "data.txt" for my program cpp_on_rails

# Get command-line arguments for filtering
filter_countries = ARGV.empty? ? nil : ARGV.map(&:upcase) # Convert to uppercase

# Command-line option parsing
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: stations_for_cpp_on_rails.rb [options] [countries]"
  
  opts.on("-n", "--normalize", "Normalize the positions") do
    options[:normalize] = true
  end
end.parse!

puts "Starting data scraping!"

SCALING_FACTOR = 5  # Adjust this value as needed, big factors separate more the nodes
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

# Generate [x, y] coords from latitude and longitude
def lat_long_to_xy(latitude, longitude, reference_lat, reference_long)
  # Convert latitude and longitude from degrees to radians
  lat_rad = latitude * Math::PI / 180
  long_rad = longitude * Math::PI / 180
  ref_lat_rad = reference_lat * Math::PI / 180
  ref_long_rad = reference_long * Math::PI / 180
  
  # Earth's radius in kilometers (average)
  earth_radius = 6371.0
  
  # Calculate differences in radians
  delta_lat = lat_rad - ref_lat_rad
  delta_long = long_rad - ref_long_rad
  
  # Calculate x and y coordinates in kilometers
  x = delta_long * earth_radius * Math.cos(ref_lat_rad)
  y = delta_lat * earth_radius
  
  return [x, y]
end

# Reference point (e.g., center of the graph)
reference_lat = 0.0   # Equator
reference_long = 0.0   # Prime Meridian

# Sort the CSV rows by country before populating the hash
STATIONS.sort_by { |row| row["country"] }.each_with_index do |row, index|
  progress_bar(index + 1, TOTAL_STATIONS, "Processing Stations")
  country = row["country"].upcase # Normalize to uppercase for comparison
  next if filter_countries && !filter_countries.include?(country) # Skip if not in filter
  next if !row["is_city"] || !row["is_main_station"] || !row["is_airport"]
  # Only add station to the hash if it's not already present (ensure uniqueness)
  node_name = format_node_name(row["name"])  # Format the node name
  unless stations_unique.key?(node_name)
    x, y = lat_long_to_xy(row["latitude"].to_f, row["longitude"].to_f, reference_lat, reference_long)
    x *= SCALING_FACTOR  # Scale x
    y *= SCALING_FACTOR  # Scale y
    stations_unique[node_name] = { country: country, x: x, y: y }
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

# Normalize positions if the option is selected
if options[:normalize]
  # Filter positions to exclude (0, 0) nodes
  valid_positions = stations_unique.values.reject { |station| station[:x] == 0 || station[:y] == 0 }

  # Get minimum x and y from valid positions
  min_x = valid_positions.map { |station| station[:x] }.min
  min_y = valid_positions.map { |station| station[:y] }.min

  puts "Normalized min values: [#{min_x}, #{min_y}]"

  stations_unique.each_with_index do |(name, station), index|
    progress_bar(index + 1, TOTAL_UNIQUE_STATIONS, "Normalizing Nodes Positions")
    station[:x] -= min_x
    station[:y] = -station[:y]
    station[:y] += min_y
  end
end

# Writing to files with a progress bar
puts

File.open(OUT_NODES_POSITIONS, 'w') do |file|
  stations_unique.each_with_index do |(name, station), index|
    progress_bar(index + 1, TOTAL_UNIQUE_STATIONS, "Writing Nodes Positions")
    file.puts("#{name} #{station[:x]} #{station[:y]}")
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
