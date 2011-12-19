module RedisConfig
  module_function

  def filename
    if Goliath.dev?
      Goliath::Application.app_path('config/dev/redis.conf')
    else
      Goliath::Application.app_path('config/prod/redis.conf')
    end
  end

  def read_file
    File.open self.filename do |f|
      f.read
    end
  end

  def value_of(key)
    if m = self.read_file.match("^\s?#{key}\s(.+)")
      m[1]
    end
  end

  def port
    if v = value_of("port")
      v
    else
      "6379"
    end
  end

  def host
    if v = value_of("bind")
      v
    else
      "127.0.0.1"
    end
  end
end

$redis = Redis.new(:host => RedisConfig.host, :port => RedisConfig.port)
