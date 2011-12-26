class PersistantHash < Hash
    require 'yaml'
    attr_accessor :filepath
    def initialize(filepath)
        @filepath = filepath
    end
    def self.load(filepath = nil)
        p = self.new(filepath)
        p.load
    end
    def exists?
      File.exists? @filepath
    end
    def load
        stored = YAML.load_file @filepath
        raise "Looks like your yaml file couldn't load: #{@filepath}" unless stored
        clear
        merge!(stored)
    end
    def save
        File.open(@filepath, 'w') {|f|
            YAML.dump(self, f)
        }
    end
end


