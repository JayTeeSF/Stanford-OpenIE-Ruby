#!/usr/bin/env ruby

#A simple Ruby wrapper for the stanford IE binary that makes it easier to use it
#on UNIX/Windows systems.
#Note: The script does some minimal sanity checking of the input, but don't
#    expect it to cover all cases. After all, it is a just a wrapper.
#Example:
#    > echo "Barack Obama was born in Hawaii." > text.txt
#    > ruby main.rb -f text.txt
#    > ruby main.rb -f text.txt,text2.txt (for batch mode).
#    Should display
#    1.000: (Barack Obama; was; born)
#    1.000: (Barack Obama; was born in; Hawaii)
#
# Ruby Version
#Authors:    JayTeeSF       <github: jayteesf>
#Version:    2017-03-05
#
# Original Python Version
#Authors:    Philippe Remy       <github: philipperemy>
#Version:    2016-07-08


# Copyright (c) 2016, Philippe Remy <github: philipperemy>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require 'fileutils'
require 'open3'

class StanfordOpenIE
  JAVA_BIN_PATH =  'java'.freeze
  DOT_BIN_PATH = 'dot'.freeze
  STANFORD_IE_FOLDER =  'stanford-openie'.freeze
  OUT_FILE = "out.txt".freeze
  OUT_DOT = 'out.dot'.freeze
  OUT_PNG = 'out.png'.freeze
  DEFAULT_INPUT_FILE = "samples.txt".freeze
  DEFAULT_INPUT_FILES = [DEFAULT_INPUT_FILE].freeze

  def initialize(options={})
    @verbose         = !!options[:verbose]
    @graphviz        = !!options[:graphviz]
    @input_files     = options[:input_files] || DEFAULT_INPUT_FILES
    @input_file_list = @input_files.reduce("") { |m, f|
      m << (f.start_with?("/") ? f : "../#{f}")
      m
    }
    @tmp_folder = '/tmp/openie/'
    unless File.exists?(@tmp_folder)
      FileUtils.mkdir_p(@tmp_folder)
    end
    @out = @tmp_folder + OUT_FILE
    @out_dot = @tmp_folder + OUT_DOT
    @out_png = @tmp_folder + OUT_PNG
  end

  def run
    if @verbose
      debug_print("Executing command = %s" % command)
    end
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      if @verbose
        while line = stdout.gets
          puts line
        end
      end
    end

    result_str = File.read(@out)

    #warn "DELETE ME: rm #{@out}"
    FileUtils.rm(@out)

    results = process_entity_relations(result_str)
    if @graphviz
      graphviz(results)
    end
    return results
  end


  private

  def process_entity_relations(entity_relations_str)
    # format is ollie.
    entity_relations_str.split("\n").map { |s|
      start_idx = s.index("(") + 1
      end_idx = s.index(")")
      (s[start_idx...end_idx].split(';'))
    }
  end

  def graphviz(results=[])
    graph = results.reduce("digraph {") {|m, er|
       m << %Q|"%s" -> "%s" [ label="%s" ];| % [er[0], er[2], er[1]]
       m
    }
    graph += "}"

    File.open(@out_dot, "w") { |f| file.puts(graph) }
    command = "%s -Tpng %s -o %s" % [DOT_BIN_PATH, @out_dot, @out_png]
    debug_print("Executing command = %s" % command) if @verbose
    %x|#{command}|

    puts "Wrote graph to %s and %s" % [@out_dot, @out_png]
  end

  def debug_print(msg)
    warn msg
  end

  def abs_path_to_script
    @abs_path_to_script = File.expand_path(File.dirname(__FILE__)) + "/"
  end

  def command
    unless @command
      @command = <<-EOF
        cd #{abs_path_to_script};
        cd #{STANFORD_IE_FOLDER};
        #{JAVA_BIN_PATH} -mx4g -cp "stanford-openie.jar:stanford-openie-models.jar:lib/*" edu.stanford.nlp.naturalli.OpenIE #{@input_file_list}  -format ollie > #{@out};
      EOF
    end
    @command
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'optparse'
  options = {verbose: false, graphviz: false}

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS]..."

    opts.on( "-g", "--graphviz", "generate graphviz") do
      options[:graphviz] = true
    end

    opts.on( "-v", "--verbose", "run in verbose mode") do
      options[:verbose] = true
    end

    opts.on( "-f [INPUT_FILE]", "--file [INPUT_FILE]", "an input file to parse") do |i|
      options[:input_files] ||= []
      options[:input_files] << i
    end

    opts.on( "-i [INPUT_FILE]", "--input_file [INPUT_FILE]", "an input file to parse") do |i|
      options[:input_files] ||= []
      options[:input_files] << i
    end

    opts.on_tail( '-h', '--help', 'This help screen' ) do
      warn opts
      exit
    end
  end
  opt_parser.parse!

  soie = StanfordOpenIE.new(options)
  puts soie.run.inspect
end
