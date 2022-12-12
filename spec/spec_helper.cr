require "spec"
require "http/client"
require "../src/ffmpeg"

unless File.exists? "./test.mp4"
  puts "downloading video file..."
  HTTP::Client.get("https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_5MB.mp4") do |response|
    raise "could not found video file" unless response.success?
    File.write("./test.mp4", response.body_io)
  end
end
