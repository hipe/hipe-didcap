require 'hipe-core/interfacey'
require 'open4'
require 'ruby-debug' # @todo
require 'json'

module Hipe
  class Didcap
    DefaultProjectName = 'default.didcap'

    include Hipe::Interfacey::Service
    interface.might do
      speaks :cli
      describe <<-desc
        didcap - capture screen at certain intervals, omitting duplicates
      desc

      default_request 'help'

      responds_to('start') do
        describe 'start the recording daemon'
        opts.on('--interval SEC', Integer,
          'min number of seconds between each frame',
          'warning -- this might change to MSEC one day [default: 5]',
          :default => '5'
        )
        optional('out-folder',
          'where to write the recorded images '<<
            "(default: \"./#{DefaultProjectName})\"",
          :default=>DefaultProjectName
        )
        opts.on('-h','--help','this screen',&help)
      end

      responds_to('stop') do
        describe 'stop the recording daemon'
        optional('out-folder',
          'which recording to stop (default: "./'<<
          "#{DefaultProjectName})\"",
          :default=>DefaultProjectName
        )
        opts.on('-h','--help','this screen',&help)
      end

      responds_to('build') do
        describe 'build playback movie from recorded images'
        optional('recording-folder',
          'where the recordings live',
          "  (default: \"#{DefaultProjectName}\")",
          :default=>DefaultProjectName
        )
        optional('out-file',
          'the name of the movie to build file',
          '  (default: "<folder>/movie.mpg")'
        )
        opts.on('-h','--help','this screen',&help)
      end

      responds_to 'help', 'this page', :aliases=>['-h','--help','-?']
    end

    def stop out_folder, opts
      @project = get_project out_folder, opts
      if @project.pid?
        maybe_kill_process @project.pid
      else
        return "no known process is running for \"#{@project.name}\"."
      end
    end

    # be922 has failed attempts at trapping interrupt signal
    def start out_folder, opts
      validate_opts opts
      @project = get_project out_folder, opts
      if @project.pid?
        puts "Process may already be running (pid ##{@project.pid}). "<<
             "Try '#{me} stop' first."
        return ''
      end
      @proxy = FfmpegProxy.new @project
      fork do
        Process.setsid
        fork do
          @project.write_pid_file
          loop do
            begin
              @proxy.capture
              sleep opts.interval
            end
          end
        end
      end
      ''
    end

    ##
    # @todo this doesn't read the manifest it just
    # uses the images. mebbe ok unless we somehow end up with a 'corrupt'
    # recording folders
    ##
    def build folder, out_path, opts
      @project = get_project folder, opts
      if out_path.nil?
        out_path = File.join(folder,'movies','movie.mpg')
      end
      unless File.directory?(File.dirname(out_path))
        FileUtils.mkdir_p(File.dirname(out_path))
      end
      if File.exist? out_path
        moved_to = Project.move_to_backup out_path
        puts "#{me}: existing movie found in target location so.."
        puts "#{me}: moving \"#{out_path}\" to \"#{moved_to}\""
      end
      images_glob = File.join(folder, 'images','%d.png')
      command = "ffmpeg -i #{images_glob} #{out_path}"
      puts "#{me} executing: \n  #{command}\n..."
      pid, stdin, stdout, stderr = Open4::popen4 command
      ignored, status = Process::waitpid2 pid
      err = stderr.read
      output = stdout.read
      # close all pipes to avoid leaks - thx unf
      [stdin,stdout,stderr].each{|pipe| pipe.close}
      if status.exitstatus != 0
        raise Fail.new("#{me} failed build to build with\n"<<
          "   #{command}\nmessage from ffmpeg: #{err}")
      end
      # raise Fail.new(stderr) unless ''==stderr
      puts "#{me}: ffmpeg response:\n"
      puts err
      if ''!=output
        raise Fail.new("not expecting any output here: #{output}")
      end
      puts "\n#{me} probably done building \"#{out_path}\"."
      ''
    end


    ############ implementation ##############

    def me
      'didcap'
    end

    def get_project folder, opts
      Project.new self, folder, opts
    end

    def maybe_kill_process pid
      puts "attempting to kill PID ##{pid}"
      begin
        rs = Process.kill('KILL', pid)
        puts(" result of kill: "<<rs.inspect)
      rescue Errno::ESRCH => e
        puts "process wasn't running"
      end
      @project.clear_pid
      'done.'
    end

    def validate_opts opts
      if opts.interval < 1 || opts.interval > 100
        raise Fail.new("interval out of range: #{opts.interval}")
      end
    end


    #
    # this is just a wrapper around the project folder and
    # whatever data files are in it, e.g pid file image files movie files
    # this is the only place that has knowledge of paths.
    #
    class Project

      # public
      def initialize controller, path, opts
        @controller = controller
        @path = path
        @opts = opts
        if ! File.directory? @path
          puts "#{me} initializing project directory:"
          mkdirs = [
            @path,
            File.join(@path, 'movies'),
            File.join(@path, 'images')
          ]
          mkdirs.each do |dir|
            puts "  mkdir #{dir}"
            FileUtils.mkdir dir
          end
        end
      end

      def pid;          pid? ? File.read(pid_filepath).to_i : nil end

      def pid?;         File.exist?(pid_filepath) end

      def clear_pid;    FileUtils.rm pid_filepath end

      def name;         @path end


      def has_images?
        puts manifest.inspect
        exit
        manifest.images.length > 0
      end

      def next_filename
        File.join(@path,'images',"#{manifest.next_index}.#{image_extension}")
      end

      def add_record_to_manifest
        manifest.add_record
      end

      def self.move_to_backup path
        before_extension, extension = /^(.+)\.([^\.]+)$/.match(path).captures
        timestamp = Time.now.strftime('%Y-%m-%d--%H-%M-%S')
        new_name = "#{before_extension}.bak.#{timestamp}.#{extension}"
        FileUtils.mv path, new_name
        new_name
      end


      # private

      def image_extension; 'png' end

      def manifest
        @manifest ||= begin
          Manifest.new File.join(@path, ManifestName)
        end
      end

      def me; @controller.me end

      def pid_filepath
        File.join @path, 'pid.txt'
      end

      def write_pid_file
        File.open(pid_filepath,'w') do |fh|
          fh.write Process.pid
        end
        puts "#{me} wrote #{pid_filepath} with pid ##{Process.pid}"
      end

      class Manifest
        attr_reader :images

        def initialize path
          if (File.exist?(path))
            puts "adding to existing images in #{path}"
          else
            puts "starting new manifest at #{path}"
            FileUtils.touch path
          end
          @fh = File.open(path,'r+')
          inner = @fh.read
          json = "[#{inner}]"
          @images = JSON.parse json
        end

        def next_index
          @images.length
        end

        def add_record
          timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
          _next_index = self.next_index
          record = {
            :index => next_index,
            :timestamp => timestamp
          }
          @images.push record
          new_line = record.to_json
          record = (0==_next_index ? '' : ",\n") << new_line
          $stdout.write record
          @fh.write record
          @fh.flush # @todo consider changing this if it gets fast
        end
      end
    end


    ManifestName = '000-manifest.txt'

    class FfmpegProxy

      def initialize project
        @project = project
      end

      def capture
        command = self.capture_command
        pid, stdin, stdout, stderr = Open4::popen4 command
        ignored, status = Process::waitpid2 pid
        err = stderr.read
        output = stdout.read
        # close all pipes to avoid leaks
        [stdin,stdout,stderr].each{|pipe| pipe.close}
        if status.exitstatus != 0
          raise Fail.new("#{@project.me} failed to capture with "<<
            " command:\n  #{command}\nresponse from ffmpeg:\n#{err}"
          )
        end
        @project.add_record_to_manifest
        nil
      end

      # private

      def capture_command
        [
          'screencapture',
          '-C', # Capture the cursor as well as the screen.  Only allowed in
            # non-interactive modes.
          # '-x', # Do not play sounds.
          '-m', # Only capture the main monitor, undefined if -i is set.
          '-t png', # <format> Image format to create, default is png
            # (other options include pdf, jpg, tiff and other formats).
            # -T  <seconds> Take the picture after a delay of <seconds>,
            # default is 5.
          @project.next_filename
        ] * ' '
      end
    end

    class Fail < RuntimeError; end
  end
end
