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
  @fixtures : Array(Fixture)? = nil

  def initialize(request)
    @directory = Dir.open(request["params"]["workspaceFolders"][0]["uri"].as_s[7..])
  end

  def initialize_response(request)
    {
      "capabilities" => {
        "implementationProvider" => true,
        "textDocumentSync"       => {
          "change" => 2,
        },
      },
    }
  end

  private def parse_line(line_no : Int32, lines)
    if /^\s*def\s*\w[\w\d]*\s*\(/.match lines.first
      if result = /^[ \t]*def\s*(\w[\w\d]*)\s*\((\s*(?:\w[\w\d]*)?\s*(?:,\s*\w[\w\d]*)*\s*)\):/im.match lines.join
        fixture_to_find = nil
        arguments = Hash(String, Tuple(Int32, Int32)).new

        name = result[1]
        if raw_arguments = result[2]
          matches = [] of Tuple(Int32, Int32, String)

          post_match = raw_arguments
          arg_start = result.begin(2).as(Int32)
          arg_line = line_no
          while match = post_match.match(/(\w[\w\d]*)/i)
            if (newline_count = match.pre_match.count '\n') > 0
              arg_line += newline_count
              arg_start = match.pre_match.split('\n').last.size
            else
              arg_start += match.begin(1).as(Int32)
            end

            matches << {arg_line, arg_start, match[1]}

            post_match = match.post_match
            arg_start += match[1].size
          end

          matches.each do |x|
            arguments[x[2]] = {x[0], x[1]}
          end
        end

        {name, line_no, result.begin(1).as Int32, arguments }
      else
        nil
      end
    end
  end

  private def get_fixtures()
    files_to_analyze = Dir.glob "#{@directory.path}/**/*.py"

    fixtures = [] of Fixture

    files_to_analyze.each do |file_path|
      File.open(file_path) do |file|
        file_lines = file.gets_to_end.split('\n').map { |x| x + '\n' }
        found_fixture = false
        line_no = -1
        file_lines.each do |line|
          line_no += 1

          if line.includes? "@pytest.fixture"
            found_fixture = true
            next
          end

          if line_info = parse_line line_no, file_lines[line_no..]
            name, line_no, col_no, arguments = line_info

            if found_fixture
              fixture = Fixture.new file_path, name, line_no, col_no, arguments
              fixtures << fixture

              found_fixture = false
            else
              next unless name.starts_with? "test_"
            end
          elsif found_fixture
            if /^\s*@/i.match(line) || /^\s*$/i.match(line)
              next
            else
              found_fixture = false
            end
          end
        end
      end
    end

    fixtures
  end

  def implementation(request)
    cur_file_path = request["params"]["textDocument"]["uri"].as_s[7..]
    position = request["params"]["position"]
    line_no_to_find = position["line"].as_i
    col_number_to_find = position["character"].as_i

    unless @fixtures
      @fixtures = get_fixtures
    end

    fixture_to_find = nil

    @fixtures.not_nil!.each do |fixture|
      break if fixture_to_find
      if fixture.@file == cur_file_path
        fixture.@arguments.each do |arg|
          if arg[1][0] == line_no_to_find
            if arg[1][1] <= col_number_to_find && col_number_to_find < arg[1][1] + arg[0].size
              fixture_to_find = arg[0]
              break
            end
          end
        end
      end
    end

    File.open("#{__DIR__}/log.txt", "a") do |file|
      file.puts fixture_to_find
    end

    result = nil

    if fixture_to_find
      @fixtures.not_nil!.each do |x|
        if x.@name == fixture_to_find
          pos = {"line" => x.@line_number, "character" => x.@col_number}
          result = {
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

    result
  end

  def onChange(request) : Nil
    @fixtures = nil
  end

  def get_response(request)
    result = (
      case request["method"].to_s
      when "initialize"
        initialize_response request
      when "textDocument/implementation"
        implementation request
      when "textDocument/didChange"
        onChange request
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
