#!/usr/bin/env ruby
require 'httparty'
require 'fileutils'
require 'uri'
require 'json'
require 'nokogiri'
require 'ruby-progressbar'

VERSION = '1.0.5'

$scripts = []

puts "daibakuhatsu v#{VERSION}"
puts "==================="
puts "\033[31;1mPlease consider buying the tracks if you want to support the artists"
puts "This script will only download the provided mp3-128 audiostreams\033[31;0m\n\n"

def open(url)
  response = HTTParty.get(url)
  return response.body
end

def download(url)
  album_url = list
  
  doc = Nokogiri::HTML(open(album_url))

  scripts = []
  variable = ""

  doc.xpath('//script').each do |script|
    scripts << script.content
  end

  # Bandcamp is great
  # Since the position of the script tag with TralbumData is unknown we need to cycle through all scripts
  scripts.each do |script|
    begin
      variable = script.match(/var\s+TralbumData\s+=\s+(.*?);/m)[1]
    rescue Exception => e
    end
  end
  object = JSON.parse variable.gsub(%r{(?://\s+.*$|"\s+\+\s+")}, '').gsub(%r{^\s*([A-Za-z0-9_\-]+)\s?:\s+}, '"\1": ')

  if object['freeDownloadPage'] != nil
    puts "\n#{object['artist']} - #{object['current']['title']} is a Free/Name your Price release! Download it here:"
    puts "#{object['freeDownloadPage']}\n\n"
  else
    path = File.expand_path "./#{object['artist']} - #{object['current']['title']}"
    FileUtils.mkdir_p(path)

    # Download cover image
    File.open "#{path}/cover.jpg", "wb" do |f|
      f.write HTTParty.get(object['artFullsizeUrl']).parsed_response
    end

    # Initiate ruby-progressbar
    format = '%t (%c/%C) [%b>%i] %e'
    total = object['trackinfo'].count
    progress = ProgressBar.create title: "Downloading #{object['artist']} - #{object['current']['title']}", format: format, starting_at: 0, total: total
    
    # Download songs
    object['trackinfo'].each do |song|
      File.open "#{path}/#{object['artist']} - #{song['title']}.mp3", "wb" do |f|
        f.write HTTParty.get(song['file']['mp3-128']).parsed_response
      end
      progress.increment
    end
    puts "Download of #{object['artist']} - #{object['current']['title']} finished!\n\n"
  end

  # Reset variables
  variable = ""
  scripts = []
end

def check(url)
  doc = Nokogiri::HTML(open(url))

  links = doc.css('a').map { |link| link['href'] }
  albums = ""
  
  links.each do |link|
    unless link == nil
      if link.match(/^\/album\//)
        link[0] = ""
        albums << " "+url+link
      end
    end
  end

  albums[0] = ""

  return albums
end

loop do
  print "Enter Bandcamp Album/Track URL: "
  page_url = gets.chomp
  list = check(page_url)
  puts list
  #download(list)
end