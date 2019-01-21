module Helpers
  module Fixtures
    PATH = File.join(File.expand_path('../..', __dir__), 'fixtures').freeze

    def read_fixture(*path)
      File.read(File.join(PATH, *path))
    end
  end
end
