module Selenium
  module WebDriver
    module Chrome
     class CommandExecutor
       HTML_TEMPLATE = "HTTP/1.1 200 OK\r\nContent-Length: %d\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n%s"
       JSON_TEMPLATE = "HTTP/1.1 200 OK\r\nContent-Length: %d\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n%s"

       def initialize
         @server       = TCPServer.new("0.0.0.0", 0)
         @queue        = Queue.new
         @accepted_any = false
         @next_socket  = nil

         Thread.new { start_run_loop }
       end

       def execute(command)
         until accepted_any?
           Thread.pass
           sleep 0.01
         end

         json = command.to_json
         data = JSON_TEMPLATE % [json.length, json]

         @next_socket.write data
         @next_socket.close

         JSON.parse read_response(@queue.pop)
       end

       def close
         close_sockets
         @server.close
       rescue IOError
         p $!, $@
         nil
       end

       def port
         @server.addr[1]
       end

       def uri
         "http://localhost:#{port}/chromeCommandExecutor"
       end

       private

       def start_run_loop
         loop do
           socket = @server.accept

           if socket.read(1) == "G" # initial GET(s)
             write_holding_page_to socket
           else
             if accepted_any?
               @queue << socket
             else
               @accepted_any = true
               read_response(socket)
             end
           end
         end
       rescue IOError, Errno::EBADF
         raise unless @server.closed?
       end

       def read_response(socket)
         result = ''
         seen_double_crlf = false
         while !socket.closed? && ((line = socket.gets.chomp) != "EOResponse")
           seen_double_crlf = true if line.empty?
           result << "#{line}\n" if seen_double_crlf
         end

         @next_socket = socket

         result.strip!
       end

       def accepted_any?
         @accepted_any
       end

       def close_sockets
         @queue.pop.close until @queue.empty?
       end

       def write_holding_page_to(socket)
         msg = "ChromeDriver server started and connected."
         socket.write HTML_TEMPLATE % [msg.length, msg]
         socket.close
       end

     end # CommandExecutor
    end # Chrome
  end # WebDriver
end # Selenium
