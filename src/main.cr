require "json"

class Fixture
  def initialize(@file : String, @name : String, @line_number : Int32, @col_number : Int32, @arguments : Hash(String, Tuple(Int32, Int32)))
  end
end

def listen_request
  length = (first_line = gets.as(String)).split(' ').last.to_i32

  slice = Bytes.new(length)

  2.times { STDIN.read_byte }
  STDIN.read_fully slice

  str = String.new slice

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
        "implementationProvider" => true,
      },
    }
  end

  private def parse_line(line_no : Int32, line : String)
    result = /\s*def\s*(\w[\w\d]*)\s*\((\s*(?:\w[\w\d]*)?\s*(?:,\s*\w[\w\d]*)*\s*)\):/.match line
    if result
      arguments = Hash(String, Tuple(Int32, Int32)).new

      name = result[1]
      if raw_arguments = result[2]
        matches = [] of Tuple(Int32, String)

        post_match = raw_arguments
        arg_start = result.begin(2).as Int32
        while match = post_match.match(/(\w[\w\d]*)/)
          matches << {arg_start + match.begin(1).as(Int32), match[1]}

          arg_start = match.end(1).as(Int32) + arg_start
          post_match = match.post_match
        end

        cur_match = 0

        matches.each do |x|
          arguments[x[1]] = {line_no, x[0]}
          cur_match += 1
        end
      end

      {name, line_no, result.begin(1).as Int32, arguments}
    else
      nil
    end
  end

  def implementation(request)
    cur_file_path = request["params"]["textDocument"]["uri"].as_s[7..]
    position = request["params"]["position"]
    line_no_to_find = position["line"].as_i
    col_number_to_find = position["character"].as_i

    files_to_analyze = Dir.glob "#{@directory.path}/**/*.py"

    fixtures = [] of Fixture

    searching_for_fixture = ""

    implementation = nil

    files_to_analyze.each do |file_path|
      File.open(file_path) do |file|
        found_fixture = false
        line_no = -1
        file.each_line do |line|
          line_no += 1

          if line.includes? "@pytest.fixture"
            found_fixture = true
            next
          end

          if line_info = parse_line line_no, line
            name, line_no, col_no, arguments = line_info

            if found_fixture
              fixture = Fixture.new file_path, name, line_no, col_no, arguments
              fixtures << fixture

              found_fixture = false
            end

            if file_path == cur_file_path && line_no == line_no_to_find
              arguments.each do |x|
                if x[1][1] <= col_number_to_find && col_number_to_find < x[1][1] + x[0].size
                  searching_for_fixture = x[0]
                  break
                end
              end
            end
          elsif found_fixture
            if /^\s*@/.match(line) || /^\s*$/.match(line)
              next
            else
              found_fixture = false
            end
          end
        end
      end
    end

    if searching_for_fixture
      fixtures.each do |x|
        if x.@name == searching_for_fixture
          pos = {"line" => x.@line_number, "character" => x.@col_number}
          implementation = {
            "uri"   => "file://" + x.@file,
            "range" => {
              "start" => pos,
              "end"   => pos,
            },
          }
          break
        end
      end
    end

    implementation
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
      "result"  => result,
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
