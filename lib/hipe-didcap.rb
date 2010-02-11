require 'hipe-core/interfacey'

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
        describe 'start recording daemon with the specified settings'
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
        describe 'stop recording'
        optional('out-folder',
          'which recording to stop (default: "./recorded-images")',
          :default=>'recorded-images'
        )
        opts.on('-h','--help','this screen',&help)
      end

      responds_to('status') do
        describe 'show status of any running daemon'
      end

      responds_to 'help', 'this page', :aliases=>['-h','--help','-?']
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
        puts "no such process"
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

    def stop out_folder, opts
      init_folder out_folder, opts
      if (!process_is_maybe_running)
        return "no known process is running."
      else
        maybe_kill_process
      end
    end

    def start out_folder, opts
      init_folder out_folder, opts
      validate_opts opts
      if process_is_maybe_running
        puts "Process may already be running (##{pid_in_file}). "<<
             "Try 'stop' first."
        return ''
      end
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
              puts("writing to logfile at "<<timestamp);
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

    # implementers:
    def timestamp
      Time.now.strftime('%Y-%m-%d--%H-%M-%S')
    end

    def validate_opts opts
      if opts.interval < 1 || opts.interval > 100
        raise Fail.new("interval out of range: #{opts.interval}")
      end
    end

    def pid_filepath
      File.join @out_path, 'pid'
    end

    def init_folder path, opts
      @out_path = path
      if ! File.directory? path
        FileUtils.mkdir path
        puts "wrote #{path}"
      end
      @log_fh = File.open(
        File.join(@out_path,'_manifest.txt'),'w'
      )
    end
  end
end
