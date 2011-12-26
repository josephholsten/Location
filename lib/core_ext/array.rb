class Array
    def merge
        self.inject({}) do |hash, item|
            hash.merge(yield(item))
        end
    end
end
