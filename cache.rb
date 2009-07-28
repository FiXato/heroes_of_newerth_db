class Cache
  class << self
    def cache_location
      @cache_location ||= File.expand_path('cache')
    end

    def ensure_cache_location
      system("mkdir -p '#{cache_location}'") unless File.exist?(cache_location)
    end

    def fetch_from_url(url)
      ensure_cache_location
      system("wget -q '#{url}' -O '#{filename_for_url(url)}'")
    end

    def filename_for_url(url)
      @filenames ||= {}
      @filenames[url] ||= File.join(cache_location,File.basename(url))
    end

    def clear
      system("rm -rf '#{cache_location}'")
    end
  end
end