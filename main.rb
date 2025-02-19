require 'net/http'
require 'json'
require 'time'

class ThreadInfo
  attr_accessor :no, :replies, :started, :lastmodified, :speed, :tim, :ext, :com, :sub, :board

  def initialize(no, replies, started, lastmodified, speed, tim, ext, com, sub, board)
    @no = no
    @replies = replies
    @started = started
    @lastmodified = lastmodified
    @speed = speed
    @tim = tim
    @ext = ext
    @com = com
    @sub = sub
    @board = board
  end
end

class Ikio
  API_URL = 'https://a.4cdn.org/'.freeze
  attr_accessor :boardname, :threads

  def initialize(boardname = 'mlp')
    @boardname = boardname
    @threads = []
  end

  def set_board(name)
    @boardname = name
  end

  def get_utc_date
    Time.now.utc.to_i
  end

  def get_json(url)
    uri = URI(url)
    response = Net::HTTP.get(uri)
    puts "Fetching: #{url}"
    puts response[0..500] # Print a snippet of the response
    JSON.parse(response) rescue nil
  end

  def get_min_since(start, nowtime)
    tpass = nowtime - start
    tpass.positive? ? (tpass / 60.0) : 1
  end

  def dl_thread_info
    url = "#{API_URL}#{@boardname}/catalog.json"
    json_threads = get_json(url)
    unless json_threads
      puts "Failed to fetch JSON"
      return false
    end
    
    puts "JSON structure: #{json_threads.class}"
    puts "First page keys: #{json_threads[0].keys}" if json_threads.is_a?(Array)
    
    nowtime = get_utc_date
    @threads.clear

    json_threads.each do |page|
      page['threads'].each do |thread|
        thread_info = ThreadInfo.new(
          thread['no'],
          thread['replies'],
          thread['time'],
          thread['time'],
          (thread['replies'].to_f / get_min_since(thread['time'], nowtime)) * 60 * 24,
          thread['tim'],
          thread['ext'],
          thread['com'],
          thread['sub'],
          @boardname
        )
        @threads << thread_info
        puts "Added thread #{thread_info.no} with #{thread_info.replies} replies"
      end
    end
    true
  end

  def insert_menu(boards, html_template)
    menu = boards.map { |board| "<a href='#{board}_rankings.html'>/#{board}/</a> " }.join(' ')
    html_template.gsub("<!--****menu****-->", menu)
  end

  def generate_html(template_file, output_file, boards, title="4chan")
    template = File.read(template_file)
    
    table_content = @threads.sort_by { |t| -t.speed }.first(50).map.with_index(1) do |thread, index|
      "<tr><td>#{index}</td><td>/#{thread.board}/</td><td><img src='http://t.4cdn.org/#{thread.board}/thumb/#{thread.tim}s.jpg'></td><td>#{thread.com}</td><td>#{thread.replies}</td><td>#{'%.3f' % thread.speed}</td><td><a href='https://boards.4chan.org/#{thread.board}/thread/#{thread.no}'>Link</a></td></tr>"
    end.join("\n")
    
    final_html = template
      .gsub("<!--****table****-->", table_content)
      .gsub("<!--****boardname****-->", title)
      .gsub("<!--****time****-->", Time.now.utc.strftime("%Y-%m-%d %H:%M:%S GMT"))
    
    final_html = insert_menu(boards, final_html)
    
    File.write(output_file, final_html)
  end

  def run
    boards = %w[vg vr vm g trash mlp pol sp v r9k fa wsg bant k]
    puts "Creating rank for each board..."
    all_threads = []
    boards.each do |board|
      set_board(board)
      if dl_thread_info
        all_threads.concat(@threads)
        generate_html('template.html', "#{board}_rankings.html", boards)
      end
    end
    
    puts "Creating overall ranking..."
    @threads = all_threads.sort_by { |t| -t.speed }
    generate_html('template.html', "index.html", boards, "4chan")
    
    puts "Done"
  end
end

ikio = Ikio.new
ikio.run
