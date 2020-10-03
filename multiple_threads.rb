# ab -n 10000 -c 100 -p ./section_one/ostechnix.txt localhost:1234/
# head -c 100000 /dev/urandom > section_one/ostechnix_big.txt

require 'socket'
require './lib/response'
require './lib/request'
MAX_EOL = 2

socket = TCPServer.new(ENV['HOST'], ENV['PORT'])

def handle_request(request_text, client)
  request = Request.new(request_text)
  puts "#{client.peeraddr[3]} #{request.path}"

  dirname = Dir.getwd
  filepath = "#{dirname}#{request.path}"

  file_content = nil

  File.open(filepath, "r") do |file|
    file_content = file.read
  end

  output = file_content.nil? ? "Hello world" : file_content

  response = Response.new(code: 200, data: output)
  response.send(client)

  client.shutdown
  puts e
end

def handle_connection(client)
  puts "Getting new client #{client}"
  request_text = ''
  eol_count = 0

  loop do
    buf = client.recv(1)
    puts "#{client} #{buf}"
    request_text += buf

    eol_count += 1 if buf == "\n"

    if eol_count == MAX_EOL
      handle_request(request_text, client)
      break
    end
  end
rescue Errno::ENOENT => e
  puts "Error: #{e}"

  response = Response.new(code: 404, data: "File Not Found")
  response.send(client)

  client.close
rescue => e
  puts "Error: #{e}"

  response = Response.new(code: 500, data: "Internal Server Error")
  response.send(client)

  client.close
end

puts "Listening on #{ENV['HOST']}:#{ENV['PORT']}. Press CTRL+C to cancel."

loop do
  Thread.start(socket.accept) do |client|
    handle_connection(client)
  end
end
