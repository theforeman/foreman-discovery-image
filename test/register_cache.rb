# frozen_string_literal: true

# Run in a disposable FDI container. Exercise the real registration loop against
# a local receiver, including the cache read after the first successful upload.
require 'json'
require 'socket'
require 'tempfile'
require 'timeout'

server = TCPServer.new('127.0.0.1', 0)
uploads = Queue.new
receiver = Thread.new do
  loop do
    client = server.accept
    begin
      request = client.gets
      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, value = line.split(':', 2)
        headers[key.downcase] = value.strip
      end
      body = client.read(Integer(headers.fetch('content-length')))
      raise 'Unexpected upload endpoint' unless request.start_with?('POST /api/v2/discovered_hosts/facts ')
      raise 'Missing facts' unless JSON.parse(body)['facts'].is_a?(Hash)

      client.write("HTTP/1.1 201 Created\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}")
      uploads << true
    ensure
      client.close
    end
  end
end

Tempfile.create('discovery-register-test') do |log|
  cmdline = "proxy.url=http://127.0.0.1:#{server.addr[1]} proxy.type=foreman fdi.uploadsleep=1"
  pid = Process.spawn({ 'FDI_CMDLINE' => cmdline }, '/usr/bin/discovery-register', out: log, err: log)
  begin
    Timeout.timeout(30) do
      uploads.pop
      sleep 0.1 until File.exist?('/tmp/proxy_cache')
    end
    cache = JSON.parse(File.read('/tmp/proxy_cache'))
    raise 'Empty fact cache' unless cache.is_a?(Hash) && !cache.empty?

    # Give the real loop time to read the cache on subsequent iterations.
    sleep 4
    raise 'Registration exited after reading its cache' if Process.waitpid(pid, Process::WNOHANG)

    puts 'Registration upload and subsequent JSON cache reads passed'
  rescue StandardError
    warn File.read(log.path)
    raise
  ensure
    begin
      Process.kill('TERM', pid)
      Process.waitpid(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      # The failed process may already have been reaped above.
    end
  end
end
receiver.kill
server.close
