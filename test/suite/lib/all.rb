require 'hipe-didcap'
# require 'fakefs'

module Hipe::BareTest
  class EvilSingleSetup
    attr_reader :component, :substitute, :value, :block
    def initialize component, &block
      @called = false
      before = instance_variables
      instance_eval(&block)
      after = instance_variables
      these = after - before
      gun_haver = self
      @block = lambda do
        these.each do |this|
          instance_variable_set this, gun_haver.instance_variable_get(this)
        end
      end
    end
  end
end

class BareTest::Suite
  def my_evil_single_setup &b
    @setup[nil] << Hipe::BareTest::EvilSingleSetup.new(self, &b)
  end
end

module Hipe::Didcap::TestSupport
  def init_didcap_project_folder dir
    if File.exist? dir
      puts ">>>>>> removing test dir #{dir}"
      FileUtils.remove_entry_secure(dir,true)
    end
    unless File.directory?(File.dirname(dir))
      puts ">>>>>>> making test dir dir #{dir}"
      FileUtils.mkdir_p(File.dirname(dir))
    end
  end
end

BareTest.suite do
  suite 'Cli' do
    suite 'typical run' do
      my_evil_single_setup do
        extend Hipe::Didcap::TestSupport
        @test_proj = './test/writable-temp/tmp-proj'
        init_didcap_project_folder @test_proj
        @app = Hipe::Didcap.new
        @app.cli_run('start', '--interval=0.25', @test_proj)
        sleep(2)
        @app.cli_run('stop',@test_proj)
        @info = @app._info @test_proj, {}
      end

      assert "duration in seconds should be about right" do
        within_delta @info[:number_of_images], 5, 3
      end

      assert "number of images should be about right" do
        within_delta @info[:duration_in_seconds], 2, 1.1
      end

      assert "movie build" do
        s = @app.cli_run('build', @test_proj)
        equal(s,"\ndidcap probably done building "<<
           "\"./test/writable-temp/tmp-proj/movies/movie.mpg\"."
        )
      end
    end
  end
end
