# ab -n 10000 -c 100 -p ./section_one/ostechnix.txt localhost:1234/
# head -c 100000 /dev/urandom > section_one/ostechnix_big.txt

require 'socket'
require 'pathname'
require 'mime-types'
require './lib/response'
require './lib/request'
MAX_EOL = 2

ROOT_PATH = '/'
DEFAULT_CONTENT_TYPE = 'plain/text'

socket = TCPServer.new(ENV['HOST'], ENV['PORT'])

def file_path(request)
  dirname = Dir.getwd

  Pathname.new("#{dirname}#{request.path}")
end

def read_file(filepath)
  file_content = nil

  File.open(filepath, "r") do |file|
    file_content = file.read
  end

  file_content
end

def handle_request(request_text, client)
  request = Request.new(request_text)
  puts "#{client.peeraddr[3]} #{request.path}"

  content_type = DEFAULT_CONTENT_TYPE

  output = if request.path == ROOT_PATH
     "Hello world"
  else
    filepath = file_path(request)
    content_type = MIME::Types.type_for(File.extname(filepath)).first
    read_file(filepath)
  end

  response = Response.new(code: 200, data: output, headers: ["Content-Type: #{content_type}"])
  response.send(client)

  client.shutdown
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
rescue Errno::EPERM => e
  puts "Error: #{e}"

  response = Response.new(code: 403, data: "Permission Denied")
  response.send(client)

  client.close
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
