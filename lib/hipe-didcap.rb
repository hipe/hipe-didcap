require 'hipe-core/interfacey'
require 'open4'
require 'ruby-debug' # @todo
require 'json'

module Hipe
  class Didcap
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
          'where to write the recorded images (default: "./recorded-images")',
          :default=>'recorded-images'
        )
        opts.on('-h','--help','this screen',&help)
      end

      responds_to('stop') do
        describe 'stop the recording daemon'
        optional('out-folder',
          'which recording to stop (default: "./recorded-images")',
          :default=>'recorded-images'
        )
        opts.on('-h','--help','this screen',&help)
      end

      responds_to('build') do
        describe 'build playback movie from recorded images'
        optional('recording-folder',
          'where the recordings live',
          '  (default: "./recorded-images")',
          :default=>'recorded-images'
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
      init_folder out_folder, opts
      if (!process_is_maybe_running)
        return "no known process is running for \"#{@path}\"."
      else
        maybe_kill_process
      end
    end

    def start out_folder, opts
      init_folder out_folder, opts
      validate_opts opts
      if process_is_maybe_running
        puts "Process may already be running (pid ##{pid_in_file}). "<<
             "Try 'stop' first."
        return ''
      end
      @proxy = FfmpegProxy.new self, out_folder, opts
      # this is process #A. it will exit immediately at end of this method
      fork do
        # this is process #B
        Process.setsid
        # after setsid this is still process #B
        fork do
          write_pid_file
          # this is process #C
          # tried trapping 'HUP', 'INT' 'KILL' 'QUIT' 'EXIT' to no avail
          trap 'KILL' do
            puts "got kill signal."
            exit 1
          end
          loop do
            begin
              @proxy.capture
              sleep(opts.interval)
              rescue Interrupt
                puts "got interrupt. exiting."
              exit
            end
          end
          # you never get here!
        end
        # this is process #B leaving
      end
      # this is process #A leaving
      ''
    end

    ##
    # @todo this doesn't read the manifest it just
    # uses the images. mebbe ok unless we somehow end up with a 'corrupt'
    # recording folders
    ##
    def build folder, out_path, opts
      init_folder folder, opts
      if out_path.nil?
        out_path = File.join(folder,'movie.mpg')
      end
      if File.exist? out_path
        moved_to = move_to_backup out_path
        puts "#{me}: existing movie found in target location so.."
        puts "#{me}: moving \"#{out_path}\" to \"#{moved_to}\""
      end
      images_glob = File.join(folder, '%d.png')
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

    def move_to_backup path
      before_extension, extension = /^(.+)\.([^\.]+)$/.match(path).captures
      timestamp = Time.now.strftime('%Y-%m-%d--%H-%M-%S')
      new_name = "#{before_extension}.bak.#{timestamp}.#{extension}"
      FileUtils.mv path, new_name
      new_name
    end

    def process_is_maybe_running
      File.exist? pid_filepath
    end

    def pid_in_file
      File.read(pid_filepath).to_i
    end

    def maybe_kill_process
      pid = pid_in_file
      puts "attempting to kill PID ##{pid}"
      begin
        rs = Process.kill('KILL', pid)
        puts(" result of kill: "<<rs.inspect)
      rescue Errno::ESRCH => e
        puts "process wasn't running"
      end
      FileUtils.rm pid_filepath
      'done.'
    end

    def write_pid_file
      File.open(pid_filepath,'w') do |fh|
        fh.write Process.pid
      end
      puts "wrote #{pid_filepath} with pid ##{Process.pid}"
    end

    def validate_opts opts
      if opts.interval < 1 || opts.interval > 100
        raise Fail.new("interval out of range: #{opts.interval}")
      end
    end

    def pid_filepath
      File.join @path, 'pid'
    end

    def init_folder path, opts
      @path = path
      if ! File.directory? path
        FileUtils.mkdir path
        puts "wrote #{path}"
      end
    end

    ManifestName = '000-manifest.txt'

    class FfmpegProxy

      def initialize controller, folder, opts
        @controller = controller
        @folder = folder
        @opts = opts
        manifest_path = File.join(@folder,ManifestName)
        if File.exist? manifest_path
          puts "continuing existing manifest: #{manifest_path}"
          @manifest = File.open(manifest_path,'r+')
          @next_index = next_index
        else
          puts "starting new manifest: #{manifest_path}"
          @manifset = File.open(manifest_path, 'a')
          @next_index = 0
        end
        raise Fail.new("where is manifest?") unless @manifest
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
          raise Fail.new("#{@controller.me} failed to capture with "<<
            " command:\n  #{command}\nresponse from ffmpeg:\n#{err}"
          )
        end
        add_record_to_manifest
        @next_index += 1
        nil
      end

      # private

      def add_record_to_manifest
        record = (0==@next_index ? '' : ",\n") <<
         "{\"index\":#{@next_index}, \"timestamp\":\"#{timestamp}\"}"
        $stdout.write record
        @manifest.write record
        @manifest.flush # @todo consider changing this if it gets fast
        nil
      end

      def timestamp
        Time.now.strftime('%Y-%m-%d %H:%M:%S')
      end

      def next_index
        inner = @manifest.read
        return 0 if "" == inner
        json = JSON.parse("[#{inner}]")
        last_index = json.last['index']
        last_index + 1
      end

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
          next_filename
        ] * ' '
      end

      def extension
        'png'
      end

      def next_filename
        File.join(@folder,"#{@next_index}.#{extension}")
      end

    end

    class Fail < RuntimeError; end
  end
end
