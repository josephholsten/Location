require 'core_ext/array'
require 'location/persistant_hash'
require 'location/fire_eagle_service'

class Location < PersistantHash
    def initialize(filepath = nil)
        super(filepath || 'location.yaml')
    end
    def self.get_current
        self.new.get_current
    end
    def get_current
        locations = FireEagleService.get_locations
        update_from_locations(locations)
    end
    def update_from_locations(locations)
        clear
        merge!(from_fire_eagle(locations))
    end
    def from_fire_eagle(fe_loc)
        best = pick_best(fe_loc)
        {
            :date => best.located_at,
            :geo => get_geo(best),
            :adr => get_adr(fe_loc)
        }
    end
    def pick_best(locations)
        locations.find {|l| l.best_guess }
    end
    def get_adr(locations)
        levels = [:country, :state, :city, :neighborhood]
        levels.merge do |level|
            { level => get_name_by_level(locations, level)}
        end
    end
    def get_name_by_level(locations, level)
        loc = locations.find {|l|
            l.level_name.to_s == level.to_s
        }
        loc.normal_name if loc
    end
    def get_geo(location)
        geo = location.geo
        {
            :long => geo.x,
            :lat => geo.y
        }
    end
end
