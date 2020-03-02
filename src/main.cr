require "json"

def listen_request
    length = (first_line = gets.as(String)).split(' ').last.to_i32

    slice = Bytes.new(length)

    2.times {STDIN.read_byte}
    STDIN.read_fully slice

    str = String.new slice
    
    File.open("#{__DIR__}/log.json", "a") do |file|
        file << first_line
        file << "\r\n"
        file << str
        file << '\n'
    end

    JSON.parse str
end

def respond_request(response)
    STDOUT << "Content-Length: #{response.bytesize}\r\n"
    STDOUT << "\r\n"
    STDOUT << response
    STDOUT.flush
end

class Lsp
    @directory : Dir

    def initialize(request)
      @directory = Dir.open(request["params"]["workspaceFolders"][0]["uri"].as_s[7..])
    end

    def initialize_response(request)
        {
            "capabilities" => {
                "implementationProvider" => true
            }
        }
    end

    def implementation(request)
        files_to_analyze = Dir.glob "#{@directory.path}/**/*.py"

        files_to_analyze.each do |file_path|
            File.open(file_path) do |file|
                file.each_line do |line|
                            
                end
            end
        end
    end

    def get_response(request)
        result = (
            case request["method"].to_s
            when "initialize"
                initialize_response request
            when "textDocument/implementation"
                implementation request
            end
        )

        response = {
            "jsonrpc" => "2.0",
            "result" => result
        }
        
        response["id"] = request["id"].to_s if request["id"]?

        response.to_json
    end
end

request = listen_request
lsp = Lsp.new request
respond_request lsp.get_response request

while true
    request = listen_request

    response = lsp.get_response request

    respond_request response
end
